import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_webrtc/telnyx_config.dart';

class ProfileModel extends ChangeNotifier {
  List<Map<String, dynamic>> profiles = [];
  int? selectedProfileIndex;

  void addProfile(Map<String, dynamic> profile) {
    profiles.add(profile);
    notifyListeners();
  }

  void removeProfile(int index) {
    if (index == selectedProfileIndex) {
      selectedProfileIndex = null;
    } else if (index < selectedProfileIndex!) {
      selectedProfileIndex = selectedProfileIndex! - 1;
    }
    profiles.removeAt(index);
    notifyListeners();
  }

  void selectProfile(int index) {
    selectedProfileIndex = index;
    notifyListeners();
  }

  Map<String, dynamic>? get selectedProfile {
    if (selectedProfileIndex == null) return null;
    return profiles[selectedProfileIndex!];
  }
}

class ProfileSwitcherBottomSheet extends StatefulWidget {
  const ProfileSwitcherBottomSheet({Key? key}) : super(key: key);

  @override
  _ProfileSwitcherBottomSheetState createState() => _ProfileSwitcherBottomSheetState();
}

class _ProfileSwitcherBottomSheetState extends State<ProfileSwitcherBottomSheet> {
  bool isTokenLogin = false;
  bool isAddingProfile = false;
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _tokenController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  void _addProfile() {
    if (!_formKey.currentState!.validate()) return;

    final profileModel = Provider.of<ProfileModel>(context, listen: false);
    Map<String, dynamic> profile;

    if (isTokenLogin) {
      profile = {
        'type': 'token',
        'token': _tokenController.text,
      };
    } else {
      profile = {
        'type': 'credentials',
        'username': _usernameController.text,
        'password': _passwordController.text,
      };
    }

    profileModel.addProfile(profile);
    setState(() {
      isAddingProfile = false;
      _usernameController.clear();
      _passwordController.clear();
      _tokenController.clear();
    });
  }

  Widget _buildAddProfileForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Switch(
                value: isTokenLogin,
                onChanged: (value) {
                  setState(() {
                    isTokenLogin = value;
                  });
                },
              ),
              const SizedBox(width: 8),
              Text(isTokenLogin ? 'Token' : 'Credentials'),
            ],
          ),
          const SizedBox(height: 16),
          if (isTokenLogin)
            TextFormField(
              controller: _tokenController,
              decoration: const InputDecoration(
                labelText: 'Token',
                border: OutlineInputBorder(),
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
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a username';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    return null;
                  },
                ),
              ],
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    isAddingProfile = false;
                  });
                },
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addProfile,
                child: const Text('Sign In'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileList() {
    return Consumer<ProfileModel>(
      builder: (context, profileModel, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListView.builder(
              shrinkWrap: true,
              itemCount: profileModel.profiles.length,
              itemBuilder: (context, index) {
                final profile = profileModel.profiles[index];
                final isSelected = index == profileModel.selectedProfileIndex;

                return ListTile(
                  title: Text(
                    profile['type'] == 'token'
                        ? 'Token Profile'
                        : profile['username'],
                  ),
                  subtitle: Text(profile['type']),
                  selected: isSelected,
                  leading: Icon(
                    isSelected ? Icons.check_circle : Icons.account_circle,
                    color: isSelected ? Theme.of(context).primaryColor : null,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => profileModel.removeProfile(index),
                  ),
                  onTap: () => profileModel.selectProfile(index),
                );
              },
            ),
            if (!isAddingProfile)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      isAddingProfile = true;
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add new profile'),
                ),
              ),
            if (isAddingProfile)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildAddProfileForm(),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          const Divider(),
          _buildProfileList(),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final profileModel = Provider.of<ProfileModel>(
                    context,
                    listen: false,
                  );
                  if (profileModel.selectedProfile != null) {
                    Navigator.pop(context, profileModel.selectedProfile);
                  }
                },
                child: const Text('Confirm'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}