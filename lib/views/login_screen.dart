// lib/views/login_screen.dart
import 'package:flutter/material.dart';
import '../app_shell.dart'; // After login we open the tabbed app shell
import '../models/session.dart';
import '../models/user_profile.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.onLoginSuccess});

  final void Function(BuildContext context, String role, String name)?
      onLoginSuccess;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final List<String> _roles = const ['Admin', 'Owner'];
  final List<String> _userNames = ['Regular User'];
  late String _selectedIdentity;
  TextEditingController? _identityController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedIdentity = _roles.first;
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final identityText = _identityController?.text.trim() ?? '';
    final identity = identityText.isNotEmpty ? identityText : _selectedIdentity;
    String role;
    UserProfile profile;

    if (_roles.contains(identity)) {
      role = identity;
      profile = UserProfiles.forRole(role);
    } else {
      role = 'User';
      if (!_userNames.contains(identity)) {
        setState(() => _userNames.add(identity));
      }
      final base = UserProfiles.forRole('User');
      final emailName = identity.toLowerCase().replaceAll(' ', '.');
      profile = UserProfile(
        name: identity,
        email: '$emailName@example.com',
        phone: base.phone,
        city: base.city,
        memberSince: base.memberSince,
        isVerified: base.isVerified,
        role: role,
      );
    }

    await Session.setUser(profile);

    if (widget.onLoginSuccess != null) {
      widget.onLoginSuccess!(context, role, profile.name);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AppShell()),
      );
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = scheme.primary;
    final onPrimary = scheme.onPrimary;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 38,
                        backgroundColor: primary.withOpacity(.15),
                        child: Icon(Icons.pets, color: primary, size: 36),
                      ),
                      const SizedBox(height: 14),
                      const Text('Welcome to PetsApp',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      const Text('Choose a profile to continue',
                          style: TextStyle(color: Colors.black54)),
                      const SizedBox(height: 24),
                      Autocomplete<String>(
                        initialValue: TextEditingValue(text: _selectedIdentity),
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          final query = textEditingValue.text.toLowerCase();
                          final options = [..._roles, ..._userNames];
                          if (query.isEmpty) return options;
                          return options
                              .where((o) => o.toLowerCase().contains(query));
                        },
                        onSelected: (value) {
                          setState(() {
                            _selectedIdentity = value;
                            _identityController?.text = value;
                          });
                        },
                        fieldViewBuilder:
                            (context, controller, focusNode, onFieldSubmitted) {
                          _identityController = controller;
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              labelText: 'Login as (type or select)',
                              hintText: 'Admin, Owner, or enter a user name',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: primary),
                              ),
                              prefixIcon: Icon(Icons.admin_panel_settings,
                                  color: primary),
                              suffixIcon:
                                  Icon(Icons.arrow_drop_down, color: primary),
                            ),
                            onChanged: (val) =>
                                setState(() => _selectedIdentity = val),
                            onSubmitted: (_) => onFieldSubmitted(),
                          );
                        },
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    color: onPrimary,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Continue',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                          onPressed: () {}, child: const Text('Need help?')),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
