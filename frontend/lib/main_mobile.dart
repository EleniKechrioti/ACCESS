import 'package:access/screens/login_screen.dart';
import 'package:access/screens/myaccount_screen.dart';
import 'package:access/screens/sign_up_screen.dart';
import 'package:access/services/notification_service.dart';
import 'package:access/services/search_service.dart';
import 'package:access/theme/app_theme.dart' as AppTheme;
import 'package:access/utils/auth_gate.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:app_links/app_links.dart';
import 'blocs/favourites_bloc/favourites_cubit.dart';
import 'blocs/location_review_cubit/location_review_cubit.dart';
import 'blocs/map_bloc/map_bloc.dart';
import 'blocs/my_account_bloc/my_account_bloc.dart';
import 'blocs/search_bloc/search_bloc.dart';
import 'screens/home_screen.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Main entry point for the application
///
/// Initializes:
/// - Flutter framework bindings
/// - Mapbox SDK with access token
/// - Firebase services
///
/// Throws:
/// - [Exception] if Mapbox access token is not provided
///
/// Usage:
/// ```bash
/// flutter run --dart-define=token=YOUR_MAPBOX_TOKEN
/// ```
Future<void> main() async {
  // Initialize Flutter framework bindings
  WidgetsFlutterBinding.ensureInitialized();

  // Load env variables
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Securely retrieve Mapbox access token from build arguments
  const ACCESS_TOKEN = String.fromEnvironment("token");

  // Validate and set Mapbox configuration
  if (ACCESS_TOKEN.isEmpty) {
    throw Exception('Missing Mapbox access token. Provide it with --dart-define=token=YOUR_TOKEN_HERE');
  }
  MapboxOptions.setAccessToken(ACCESS_TOKEN);

  // Initialize Firebase for the application. This sets up the connection to your Firebase project.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Instantiate the NotificationService. This will trigger the factory constructor
  // and ensure the singleton instance (_instance) is initialized.
  NotificationService();

  // Access the singleton instance of NotificationService and call its initialization method.
  // This is where you set up notification channels and listeners.
  await NotificationService.instance.init();

  // Set the handler for background Firebase Messaging events. This function
  // (_firebaseMessagingBackgroundHandler) will be executed in a separate isolate
  // when the app is in the background or terminated and receives a message.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Launch the application with BLoC provider
  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider<MyAccountBloc>(
          create: (_) => MyAccountBloc()..add(LoadUserProfile()),
        ),
        BlocProvider<MapBloc>(
          create: (_) => MapBloc()..add(RequestLocationPermission()),
        ),
        BlocProvider<SearchBloc>(
          create: (_) => SearchBloc(searchService: SearchService()),
        ),
        BlocProvider(
          create: (_) => FavoritesCubit(),
        ),
        BlocProvider(
          create: (_) => LocationCommentsCubit(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}
/// Creates a global key that can be used to access the Navigator state
/// from anywhere in the application. This is particularly useful for
/// performing navigation from outside the typical widget build context,
/// such as within notification handlers or background processes.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final supabase = Supabase.instance.client;


class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _appLinks = AppLinks();
  Uri? _currentUri;

  @override
  void initState() {
    super.initState();
    //_init();
  }

  Future<void> _init() async {
    final appLink = await _appLinks.getInitialLink();
    if (appLink != null) {
      _handleIncomingLink(appLink);
    }

    _appLinks.uriLinkStream.listen((uri) {
      if (!mounted) {
        return;
      }
      _handleIncomingLink(uri);
    }, onError: (err) {
      print('Error receiving URI: $err');
    });
  }

  void _handleIncomingLink(Uri uri) {
    setState(() {
      _currentUri = uri;
    });
    if (uri.scheme == 'https://accessiblecity.gr' && uri.host == 'location') {
      String? locationId = uri.queryParameters['id'];
      if (locationId != null) {
        print('Opened with location ID: $locationId');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Mapbox Search App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      supportedLocales: const [
        Locale('en'),
        Locale('el'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: '/home',
      routes: {
        '/home': (context) => const HomePage(),
        '/signup': (context) => SignUpPage(),
        '/profile': (context) => AuthGate(),
        '/login': (context) => LoginScreen(),
        '/myaccount': (context) => BlocListener<MyAccountBloc, MyAccountState>(
          listener: (context, state) {
            if (state is MyAccountSignedOut) {
              Navigator.pushReplacementNamed(context, '/login');
            }
          },
          child: const MyAccountScreen(),
        ),
      },
    );
  }
}