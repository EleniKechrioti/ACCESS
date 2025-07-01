import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../blocs/location_review_cubit/location_review_cubit.dart';
import '../models/comment.dart';
import 'package:firebase_storage/firebase_storage.dart';

class PublishCommentModal extends StatefulWidget {
  /// ID of the location this comment belongs to
  final String locationId;
  const PublishCommentModal({required this.locationId, Key? key}) : super(key: key);

  @override
  _PublishCommentModalState createState() => _PublishCommentModalState();
}

class _PublishCommentModalState extends State<PublishCommentModal> {
  /// Controller to manage the comment text input
  final _textController = TextEditingController();

  /// Selected image file for the comment, if any
  File? _pickedImage;

  /// Indicates if a submission/upload is in progress
  bool _loading = false;

  /// Image picker instance to select images from gallery
  final _picker = ImagePicker();

  /// Opens the device gallery to pick an image
  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() {
        _pickedImage = File(picked.path);
      });
    }
  }

  /// Uploads the selected image to Firebase Storage and returns its download URL
  Future<String?> _uploadImage(File file) async {
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('comments_images/${DateTime.now().millisecondsSinceEpoch}.jpg');
    final uploadTask = storageRef.putFile(file);
    final snapshot = await uploadTask.whenComplete(() {});
    final url = await snapshot.ref.getDownloadURL();
    return url;
  }

  /// Handles submitting the comment along with optional image upload
  Future<void> _submit() async {
    /// Validate that there is at least text or image
    if (_textController.text.isEmpty && _pickedImage == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Πρέπει να προσθέσεις σχόλιο ή φωτογραφία')));
      return;
    }

    setState(() { _loading = true; });

    String? photoUrl;
    if (_pickedImage != null) {
      photoUrl = await _uploadImage(_pickedImage!);
    }

    /// Create a comment object to send
    final comment = Comment(
      id: Uuid().v4(),
      userId: FirebaseAuth.instance.currentUser!.uid,
      photoUrl: photoUrl,
      text: _textController.text.isEmpty ? null : _textController.text,
      timestamp: DateTime.now(),
    );

    /// Add the comment using the cubit
    await context.read<LocationCommentsCubit>().addComment(widget.locationId, comment);

    setState(() { _loading = false; });
    Navigator.of(context).pop(true); // Close the modal, indicate success
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Νέα Δημοσίευση', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Γράψε σχόλιο...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (_pickedImage != null)
              Image.file(_pickedImage!, height: 150),
            TextButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo_library),
              label: const Text('Προσθήκη φωτογραφίας'),
            ),
            const SizedBox(height: 12),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: _submit,
              child: const Text('Δημοσίευσε'),
            ),
          ],
        ),
      ),
    );
  }
}
