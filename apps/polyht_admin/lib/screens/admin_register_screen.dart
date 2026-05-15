import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../config/college_data.dart';
import '../providers/auth_provider.dart';

class AdminRegisterScreen extends StatefulWidget {
  const AdminRegisterScreen({super.key});

  @override
  State<AdminRegisterScreen> createState() => _AdminRegisterScreenState();
}

class _AdminRegisterScreenState extends State<AdminRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _middleName = TextEditingController();
  final _lastName = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _college = polytechnicColleges.first;
  String? _state = 'Himachal Pradesh';
  bool _obscurePassword = true;

  @override
  void dispose() {
    _firstName.dispose();
    _middleName.dispose();
    _lastName.dispose();
    _mobile.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Registration')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Create admin account', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _field(_firstName, 'First Name', Icons.person_outline, required: true),
                            _field(_middleName, 'Middle Name', Icons.person_outline),
                            _field(_lastName, 'Last Name', Icons.person_outline, required: true),
                            _field(_mobile, 'Mobile', Icons.phone_outlined, keyboardType: TextInputType.phone, required: true),
                            _field(_email, 'Email', Icons.email_outlined, keyboardType: TextInputType.emailAddress, required: true, email: true),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: TextEditingController(text: _college ?? ''),
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'College',
                            prefixIcon: Icon(Icons.account_balance_outlined),
                            suffixIcon: Icon(Icons.search_rounded),
                          ),
                          onTap: _pickCollege,
                          validator: (_) => _college == null || _college!.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _state,
                          decoration: const InputDecoration(labelText: 'State', prefixIcon: Icon(Icons.map_outlined)),
                          isExpanded: true,
                          items: indianStates.map((state) => DropdownMenuItem(value: state, child: Text(state))).toList(),
                          onChanged: (value) => setState(() => _state = value),
                          validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _password,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          validator: (value) {
                            final text = value ?? '';
                            if (text.length < 8) return 'Minimum 8 characters';
                            if (!RegExp(r'[A-Z]').hasMatch(text) || !RegExp(r'[a-z]').hasMatch(text) || !RegExp(r'\d').hasMatch(text) || !RegExp(r'[^A-Za-z0-9]').hasMatch(text)) {
                              return 'Use upper, lower, number and symbol';
                            }
                            return null;
                          },
                        ),
                        if (auth.error != null) ...[
                          const SizedBox(height: 12),
                          Text(auth.error!.replaceAll('Exception: ', ''), style: const TextStyle(color: AppTheme.error)),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: auth.isLoading ? null : _submit,
                            child: auth.isLoading
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                                : const Text('Register'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool required = false,
    bool email = false,
    TextInputType? keyboardType,
  }) {
    return SizedBox(
      width: 290,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (required && text.isEmpty) return 'Required';
          if (email && text.isNotEmpty && !text.contains('@')) return 'Enter a valid email';
          return null;
        },
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await context.read<AuthProvider>().registerAdmin(
          firstName: _firstName.text.trim(),
          middleName: _middleName.text.trim(),
          lastName: _lastName.text.trim(),
          mobile: _mobile.text.trim(),
          email: _email.text.trim(),
          college: _college!,
          state: _state!,
          password: _password.text,
        );
    if (!mounted || !ok) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application submitted. Superuser approval is required before sign in.')));
    Navigator.of(context).pop();
  }

  Future<void> _pickCollege() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => const _CollegeSearchDialog(),
    );
    if (selected != null) setState(() => _college = selected);
  }
}

class _CollegeSearchDialog extends StatefulWidget {
  const _CollegeSearchDialog();

  @override
  State<_CollegeSearchDialog> createState() => _CollegeSearchDialogState();
}

class _CollegeSearchDialogState extends State<_CollegeSearchDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final results = polytechnicColleges
        .where((college) => college.toLowerCase().contains(_query.trim().toLowerCase()))
        .take(80)
        .toList();
    return AlertDialog(
      title: const Text('Choose college'),
      content: SizedBox(
        width: 520,
        height: 460,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), labelText: 'Search polytechnic college'),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final college = results[index];
                  return ListTile(
                    title: Text(college),
                    onTap: () => Navigator.of(context).pop(college),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
