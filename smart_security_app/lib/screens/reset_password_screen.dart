import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({Key? key}) : super(key: key);

  @override
  _ResetPasswordScreenState createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String _message = '';
  bool _isError = false;

  Future<void> _resetPassword() async {
    setState(() {
      _isLoading = true;
      _message = '';
      _isError = false;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      setState(() {
        _message = 'Un email de réinitialisation a été envoyé.';
        _isError = false;
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _message = e.message ?? 'Une erreur est survenue';
        _isError = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Réinitialiser'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                LucideIcons.keyRound,
                size: 80,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 24),
              const Text(
                'Mot de passe oublié ?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Entrez votre email pour recevoir un lien de réinitialisation.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(LucideIcons.mail),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              if (_message.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  _message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isError ? AppTheme.riskHigh : AppTheme.riskLow,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _resetPassword,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Envoyer le lien'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
