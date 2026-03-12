import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/backend_helper.dart';

class BackendUploadWidget extends StatefulWidget {
  const BackendUploadWidget({super.key});

  @override
  State<BackendUploadWidget> createState() => _BackendUploadWidgetState();
}

class _BackendUploadWidgetState extends State<BackendUploadWidget> {
  bool _isUploading = false;
  bool _isTesting = false;
  String? _uploadedImageUrl;
  List<Map<String, dynamic>> _files = [];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Test Connection Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Backend Connection',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _isTesting ? null : _testBackendConnection,
                    child: _isTesting
                        ? const CircularProgressIndicator()
                        : const Text('Test Backend Connection'),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Upload Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Upload to Backend',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isUploading ? null : _uploadFromCamera,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Camera'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isUploading ? null : _uploadFromGallery,
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Gallery'),
                        ),
                      ),
                    ],
                  ),
                  if (_isUploading) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    const Text('Uploading...'),
                  ],
                  if (_uploadedImageUrl != null) ...[
                    const SizedBox(height: 16),
                    const Text('Upload successful!', 
                        style: TextStyle(color: Colors.green)),
                    const SizedBox(height: 8),
                    Text(
                      'URL: $_uploadedImageUrl',
                      style: const TextStyle(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Files List Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Backend Files',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _loadFiles,
                    child: const Text('Refresh Files'),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: _files.isEmpty
                        ? const Center(child: Text('No files found'))
                        : ListView.builder(
                            itemCount: _files.length,
                            itemBuilder: (context, index) {
                              final file = _files[index];
                              return ListTile(
                                title: Text(
                                  file['key'].split('/').last,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text('${file['size']} bytes'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteFile(file['key']),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _testBackendConnection() async {
    setState(() {
      _isTesting = true;
    });

    try {
      bool isAvailable = await BackendHelper.isBackendAvailable(context);
      
      if (isAvailable) {
        // Get bucket info
        final bucketInfo = await BackendHelper.getBackendBucketInfo();
        if (bucketInfo['success']) {
          BackendHelper.showBackendSnackbar(
            context,
            'Backend connected! Bucket: ${bucketInfo['bucket']['name']}',
          );
        }
      }
    } finally {
      setState(() {
        _isTesting = false;
      });
    }
  }

  Future<void> _uploadFromCamera() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      await _uploadFile(File(image.path));
    }
  }

  Future<void> _uploadFromGallery() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      await _uploadFile(File(image.path));
    }
  }

  Future<void> _uploadFile(File file) async {
    setState(() {
      _isUploading = true;
      _uploadedImageUrl = null;
    });

    try {
      // Check backend availability first
      bool isAvailable = await BackendHelper.isBackendAvailable(context);
      if (!isAvailable) return;

      // Upload image
      String? url = await BackendHelper.uploadImageToBackend(
        file,
        folder: 'flutter-uploads',
      );

      if (url != null) {
        setState(() {
          _uploadedImageUrl = url;
        });
        BackendHelper.showBackendSnackbar(
          context,
          'Image uploaded successfully via backend!',
        );
        // Refresh files list
        _loadFiles();
      } else {
        BackendHelper.showBackendSnackbar(
          context,
          'Upload failed',
          isError: true,
        );
      }
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _loadFiles() async {
    try {
      bool isAvailable = await BackendHelper.isBackendAvailable(context);
      if (!isAvailable) return;

      final files = await BackendHelper.getBackendFiles(prefix: 'flutter-uploads');
      setState(() {
        _files = files;
      });
    } catch (e) {
      BackendHelper.showBackendSnackbar(
        context,
        'Failed to load files: $e',
        isError: true,
      );
    }
  }

  Future<void> _deleteFile(String objectName) async {
    try {
      bool success = await BackendHelper.deleteBackendFile(objectName);
      if (success) {
        BackendHelper.showBackendSnackbar(context, 'File deleted successfully');
        _loadFiles(); // Refresh the list
      } else {
        BackendHelper.showBackendSnackbar(
          context,
          'Failed to delete file',
          isError: true,
        );
      }
    } catch (e) {
      BackendHelper.showBackendSnackbar(
        context,
        'Delete error: $e',
        isError: true,
      );
    }
  }
}
