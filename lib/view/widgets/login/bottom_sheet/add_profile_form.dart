import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_flutter_webrtc/model/profile_model.dart';
import 'package:telnyx_flutter_webrtc/provider/profile_provider.dart';
import 'package:telnyx_flutter_webrtc/utils/dimensions.dart';
import 'package:telnyx_flutter_webrtc/utils/theme.dart';

class FieldTitle extends StatelessWidget {
  final String title;

  const FieldTitle({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: spacingXS),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class CredentialToggle extends StatelessWidget {
  final bool isTokenLogin;
  final ValueChanged<bool> onToggleChanged;

  const CredentialToggle({
    Key? key,
    required this.isTokenLogin,
    required this.onToggleChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onToggleChanged(false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: spacingM, horizontal: spacingL),
                decoration: BoxDecoration(
                  color: !isTokenLogin ? active_text_field_color : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                ),
                child: Text(
                  'Credential Login',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: !isTokenLogin ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => onToggleChanged(true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: spacingM, horizontal: spacingL),
                decoration: BoxDecoration(
                  color: isTokenLogin ? active_text_field_color : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: Text(
                  'Token Login',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isTokenLogin ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AddProfileForm extends StatefulWidget {
  final Profile? existingProfile;
  final VoidCallback onCancelPressed;

  const AddProfileForm({Key? key, required this.onCancelPressed, this.existingProfile})
      : super(key: key);

  @override
  _AddProfileFormState createState() => _AddProfileFormState();
}

class _AddProfileFormState extends State<AddProfileForm> {
  bool _isTokenLogin = false;
  bool _isPasswordVisible = false;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _tokenController = TextEditingController();
  final _sipUserController = TextEditingController();
  final _sipPasswordController = TextEditingController();
  final _sipCallerIDNameController = TextEditingController();
  final _sipCallerIDNumberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.existingProfile != null) {
      final profile = widget.existingProfile!;
      _isTokenLogin = profile.isTokenLogin;
      _tokenController.text = profile.token;
      _sipUserController.text = profile.sipUser;
      _sipPasswordController.text = profile.sipPassword;
      _sipCallerIDNameController.text = profile.sipCallerIDName;
      _sipCallerIDNumberController.text = profile.sipCallerIDNumber;
    }
  }

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
          CredentialToggle(
            isTokenLogin: _isTokenLogin,
            onToggleChanged: (value) {
              setState(() {
                _isTokenLogin = value;
              });
            },
          ),
          const SizedBox(height: spacingL),
          if (_isTokenLogin) ...[
            const FieldTitle(title: 'Token'),
            TextFormField(
              controller: _tokenController,
              decoration: const InputDecoration(
                hintText: 'Enter your token',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a token';
                }
                return null;
              },
            ),
          ] else ...[
            const FieldTitle(title: 'SIP Username'),
            TextFormField(
              controller: _sipUserController,
              decoration: const InputDecoration(
                hintText: 'Enter your SIP username',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a SIP username';
                }
                return null;
              },
            ),
            const SizedBox(height: spacingM),
            const FieldTitle(title: 'SIP Password'),
            TextFormField(
              controller: _sipPasswordController,
              decoration: InputDecoration(
                hintText: 'Enter your SIP password',
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
              ),
              obscureText: !_isPasswordVisible,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a SIP password';
                }
                return null;
              },
            ),
          ],
          const SizedBox(height: spacingM),
          const FieldTitle(title: 'Caller ID Name'),
          TextFormField(
            controller: _sipCallerIDNameController,
            decoration: const InputDecoration(
              hintText: 'Enter your caller ID name',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a caller ID name';
              }
              return null;
            },
          ),
          const SizedBox(height: spacingM),
          const FieldTitle(title: 'Caller ID Number'),
          TextFormField(
            controller: _sipCallerIDNumberController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
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
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const Spacer(),
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
