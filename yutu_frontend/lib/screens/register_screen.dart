import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  Future<void> _submitRegister() async {
    if (_formKey.currentState!.validate()) {
      final error = await Provider.of<AuthProvider>(context, listen: false).register(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _nameController.text.trim(),
      );

      if (!mounted) return;

      if (error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('register_success_msg'.tr()), backgroundColor: Colors.green),
        );
        Navigator.pop(context); // Vrátí uživatele zpět na přihlášení
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      appBar: AppBar(title: Text('create_account_title'.tr())),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.person_add, size: 80, color: Colors.deepPurple),
                const SizedBox(height: 32),
                
                TextFormField(
                  controller: _nameController,
                  decoration:  InputDecoration(labelText: 'full_name'.tr(), prefixIcon: Icon(Icons.person)),
                  validator: (val) => val!.isEmpty ? 'required_field'.tr() : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email)),
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) => val!.isEmpty ? 'required_field'.tr() : null,
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(labelText: 'password_label'.tr(), prefixIcon: const Icon(Icons.lock)),
                  obscureText: true,
                  validator: (val) => val!.length < 6 ? 'error_min_6_chars'.tr() : null,
                ),
                const SizedBox(height: 24),
                
                ElevatedButton(
                  onPressed: isLoading ? null : _submitRegister,
                  child: isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : Text('sign_up_btn'.tr()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}