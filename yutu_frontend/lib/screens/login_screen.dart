import 'package:easy_localization/easy_localization.dart';
import 'main_layout_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  final _formKey = GlobalKey<FormState>();

  Future<void> _submitLogin() async {
    // Check if the form is valid (e.g., fields aren't empty)
    if (_formKey.currentState!.validate()) {
    
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Attempt login
      final success = await authProvider.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

     if (success) {
        // Navigate to the MainLayoutScreen and DESTROY all previous history
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const MainLayoutScreen()),
            (Route<dynamic> route) => false, 
          );
        }
      } else {
        // If it fails, show an error
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
              content: Text('login_failed_msg'.tr()),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      appBar: AppBar(title: Text('login_title'.tr())),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.gavel, size: 80, color: Colors.deepPurple),
                const SizedBox(height: 32),
                
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) => value!.isEmpty ? 'error_empty_email'.tr() : null,
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _passwordController,
                  decoration:  InputDecoration(
                    labelText: 'password_label'.tr(),
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                  validator: (value) => value!.isEmpty ? 'error_empty_password'.tr() : null,
                ),
                const SizedBox(height: 24),
                
                ElevatedButton(
                  onPressed: isLoading ? null : _submitLogin,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: isLoading 
                    ? const CircularProgressIndicator() 
                    : Text('login_btn'.tr(), style: const TextStyle(fontSize: 16)),
                ),
                
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RegisterScreen()),
                    );
                  },
                  child: Text('no_account_signup'.tr()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}