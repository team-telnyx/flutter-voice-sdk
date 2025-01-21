import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_flutter_webrtc/model/profile_model.dart';
import 'package:telnyx_flutter_webrtc/provider/profile_provider.dart';
import 'package:telnyx_flutter_webrtc/utils/dimensions.dart';

class AddProfileForm extends StatefulWidget {
  final VoidCallback onCancelPressed;

  const AddProfileForm({Key? key, required this.onCancelPressed})
      : super(key: key);

  @override
  _AddProfileFormState createState() => _AddProfileFormState();
}

class _AddProfileFormState extends State<AddProfileForm> {
  bool _isTokenLogin = false;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _tokenController = TextEditingController();
  final _sipUserController = TextEditingController();
  final _sipPasswordController = TextEditingController();
  final _sipCallerIDNameController = TextEditingController();
  final _sipCallerIDNumberController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _tokenController.dispose();
    _sipUserController.dispose();
    _sipPasswordController.dispose();
    _sipCallerIDNameController.dispose();
    _sipCallerIDNumberController.dispose();
    super.dispose();
  }

  void _resetForm() {
    _nameController.clear();
    _tokenController.clear();
    _sipUserController.clear();
    _sipPasswordController.clear();
    _sipCallerIDNameController.clear();
    _sipCallerIDNumberController.clear();
    _isTokenLogin = false;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: spacingM),
          Row(
            children: [
              Switch(
                value: _isTokenLogin,
                onChanged: (value) {
                  setState(() {
                    _isTokenLogin = value;
                  });
                },
              ),
              const SizedBox(width: spacingS),
              Text(_isTokenLogin ? 'Token Login' : 'Credential Login'),
            ],
          ),
          const SizedBox(height: spacingM),
          if (_isTokenLogin)
            TextFormField(
              controller: _tokenController,
              decoration: const InputDecoration(
                labelText: 'Token',
                hintText: 'Enter your token',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a token';
                }
                return null;
              },
            )
          else
            Column(
              children: [
                TextFormField(
                  controller: _sipUserController,
                  decoration: const InputDecoration(
                    labelText: 'SIP Username',
                    hintText: 'Enter your SIP username',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a SIP username';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: spacingS),
                TextFormField(
                  controller: _sipPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'SIP Password',
                    hintText: 'Enter your SIP password',
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a SIP password';
                    }
                    return null;
                  },
                ),
              ],
            ),
          const SizedBox(height: spacingM),
          TextFormField(
            controller: _sipCallerIDNameController,
            decoration: const InputDecoration(
              labelText: 'Caller ID Name',
              hintText: 'Enter your caller ID name',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a caller ID name';
              }
              return null;
            },
          ),
          const SizedBox(height: spacingS),
          TextFormField(
            controller: _sipCallerIDNumberController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Caller ID Number',
              hintText: 'Enter your caller ID number',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a caller ID number';
              }
              return null;
            },
          ),
          const SizedBox(height: spacingL),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _resetForm();
                  });
                  widget.onCancelPressed();
                },
                child: const Text('Cancel'),
              ),
              const SizedBox(width: spacingM),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    final profile = Profile(
                      isTokenLogin: _isTokenLogin,
                      token: _tokenController.text,
                      sipUser: _sipUserController.text,
                      sipPassword: _sipPasswordController.text,
                      sipCallerIDName: _sipCallerIDNameController.text,
                      sipCallerIDNumber: _sipCallerIDNumberController.text,
                    );

                    try {
                      context.read<ProfileProvider>().addProfile(profile);
                      setState(() {
                        _resetForm();
                      });
                      widget.onCancelPressed();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString())),
                      );
                    }
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
