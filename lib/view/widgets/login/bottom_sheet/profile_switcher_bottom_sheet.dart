import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_flutter_webrtc/model/profile_model.dart';
import 'package:telnyx_flutter_webrtc/provider/profile_provider.dart';
import 'package:telnyx_flutter_webrtc/utils/dimensions.dart';

class ProfileSwitcherBottomSheet extends StatefulWidget {
  const ProfileSwitcherBottomSheet({super.key});

  @override
  State<ProfileSwitcherBottomSheet> createState() =>
      _ProfileSwitcherBottomSheetState();
}

class _ProfileSwitcherBottomSheetState extends State<ProfileSwitcherBottomSheet> {
  bool _isAddingProfile = false;
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

  Widget _buildProfileList() {
    return Consumer<ProfileProvider>(
      builder: (context, provider, child) {
        if (provider.profiles.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No profiles yet'),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          itemCount: provider.profiles.length,
          itemBuilder: (context, index) {
            final profile = provider.profiles[index];
            final isSelected = provider.selectedProfile?.name == profile.name;

            return ListTile(
              title: Text(profile.name),
              subtitle: Text(profile.isTokenLogin ? 'Token' : 'Credentials'),
              selected: isSelected,
              selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
              leading: Icon(
                profile.isTokenLogin ? Icons.key : Icons.person,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).iconTheme.color,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => provider.removeProfile(profile.name),
              ),
              onTap: () => provider.selectProfile(profile.name),
            );
          },
        );
      },
    );
  }

  Widget _buildAddProfileForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Profile Name',
              hintText: 'Enter a name for this profile',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a profile name';
              }
              return null;
            },
          ),
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
                    _isAddingProfile = false;
                    _resetForm();
                  });
                },
                child: const Text('Cancel'),
              ),
              const SizedBox(width: spacingM),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    final profile = Profile(
                      name: _nameController.text,
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
                        _isAddingProfile = false;
                        _resetForm();
                      });
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Existing Profiles',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (!_isAddingProfile)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _isAddingProfile = true;
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add new profile'),
                ),
            ],
          ),
          const SizedBox(height: spacingM),
          if (_isAddingProfile)
            _buildAddProfileForm()
          else
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildProfileList(),
                  const SizedBox(height: spacingL),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: spacingM),
                      ElevatedButton(
                        onPressed: context.watch<ProfileProvider>().selectedProfile != null
                            ? () => Navigator.pop(context)
                            : null,
                        child: const Text('Confirm'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}