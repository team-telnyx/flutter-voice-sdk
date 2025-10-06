import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_flutter_webrtc/view/telnyx_client_view_model.dart';
import 'package:telnyx_webrtc/model/transcript_item.dart';

class TranscriptDialog extends StatefulWidget {
  const TranscriptDialog({super.key});

  @override
  State<TranscriptDialog> createState() => _TranscriptDialogState();
}

class _TranscriptDialogState extends State<TranscriptDialog> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  File? _selectedImage;
  String? _selectedImageBase64;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image != null) {
        final File imageFile = File(image.path);
        final Uint8List imageBytes = await imageFile.readAsBytes();
        final String base64String = base64Encode(imageBytes);
        
        setState(() {
          _selectedImage = imageFile;
          _selectedImageBase64 = base64String;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _selectedImageBase64 = null;
    });
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isNotEmpty || _selectedImageBase64 != null) {
      final messageText = message.isNotEmpty ? message : 'Image attached';
      context.read<TelnyxClientViewModel>().sendConversationMessage(
        messageText,
        base64Image: _selectedImageBase64,
      );
      _messageController.clear();
      _removeImage();
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.chat, color: Colors.white),
              const SizedBox(width: 8),
              const Text(
                'Assistant Conversation',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ],
          ),
        ),
        // Transcript list
        Expanded(
          child: Consumer<TelnyxClientViewModel>(
            builder: (context, viewModel, child) {
              final transcript = viewModel.transcript;

              // Auto-scroll when new messages arrive
              if (transcript.isNotEmpty) {
                _scrollToBottom();
              }

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: transcript.length,
                itemBuilder: (context, index) {
                  final item = transcript[index];
                  return _TranscriptMessage(key: ValueKey(item.id), item: item);
                },
              );
            },
          ),
        ),
        // Message input
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border(
              top: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          child: Column(
            children: [
              // Image preview
              if (_selectedImage != null) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.file(
                          _selectedImage!,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Image selected',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _removeImage,
                        icon: const Icon(Icons.close, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.red[100],
                          foregroundColor: Colors.red,
                          minimumSize: const Size(32, 32),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Input row
              Row(
                children: [
                  IconButton(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.image),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      foregroundColor: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send),
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TranscriptMessage extends StatelessWidget {
  const _TranscriptMessage({super.key, required this.item});

  final TranscriptItem item;

  @override
  Widget build(BuildContext context) {
    final isUser = item.role == 'user';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue[100],
              child: const Icon(Icons.smart_toy, size: 16, color: Colors.blue),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isUser ? Colors.blue[500] : Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Display text content if available
                  if (item.content.isNotEmpty) ...[
                    Text(
                      item.content,
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (item.hasImages()) const SizedBox(height: 8),
                  ],
                  // Display images if available
                  if (item.hasImages()) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: item.imageUrls!.map((imageUrl) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _DataUrlImage(
                            dataUrl: imageUrl,
                            width: 100,
                            height: 100,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _formatTimestamp(item.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: isUser ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.green[100],
              child: const Icon(Icons.person, size: 16, color: Colors.green),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }
}

class _DataUrlImage extends StatefulWidget {
  const _DataUrlImage({
    required this.dataUrl,
    this.width = 100,
    this.height = 100,
  });

  final String dataUrl;
  final double width;
  final double height;

  @override
  State<_DataUrlImage> createState() => _DataUrlImageState();
}

class _DataUrlImageState extends State<_DataUrlImage> {
  Uint8List? _imageData;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _decodeDataUrl();
  }

  @override
  void didUpdateWidget(_DataUrlImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dataUrl != oldWidget.dataUrl) {
      _decodeDataUrl();
    }
  }

  void _decodeDataUrl() {
    setState(() {
      _imageData = null;
      _error = null;
    });
    try {
      final uri = Uri.parse(widget.dataUrl);
      if (uri.scheme != 'data') {
        throw const FormatException('Invalid scheme: expected "data"');
      }
      _imageData = uri.data!.contentAsBytes();
    } catch (e) {
      _error = e;
    } finally {
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _imageErrorWidget();
    }

    if (_imageData == null) {
      return Container(
        width: widget.width,
        height: widget.height,
        color: Colors.grey[300],
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Image.memory(
      _imageData!,
      width: widget.width,
      height: widget.height,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _imageErrorWidget(),
    );
  }

  Widget _imageErrorWidget() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey[300],
      child: const Icon(Icons.image_not_supported),
    );
  }
}
