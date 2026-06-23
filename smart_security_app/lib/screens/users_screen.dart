import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({Key? key}) : super(key: key);

  @override
  _UsersScreenState createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _message = '';
  bool _isError = false;

  Future<void> _createUser() async {
    setState(() {
      _isLoading = true;
      _message = '';
      _isError = false;
    });

    try {
      // Pour créer un utilisateur sans déconnecter l'admin actuel,
      // on utilise une instance secondaire temporaire de Firebase.
      FirebaseApp tempApp = await Firebase.initializeApp(
        name: 'tempAppForCreation',
        options: Firebase.app().options,
      );

      await FirebaseAuth.instanceFor(app: tempApp).createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      await tempApp.delete();

      setState(() {
        _message = 'Utilisateur ajouté avec succès !';
        _isError = false;
        _emailController.clear();
        _passwordController.clear();
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _message = e.message ?? 'Une erreur est survenue';
        _isError = true;
      });
    } catch (e) {
      setState(() {
        _message = 'Erreur: $e';
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
        title: const Text('Gestion Utilisateurs'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                LucideIcons.users,
                size: 80,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 24),
              const Text(
                'Ajouter un Accès',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Créez un nouveau compte pour permettre à une autre personne d\'accéder au système.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email du nouvel utilisateur',
                  prefixIcon: Icon(LucideIcons.mail),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Mot de passe (6 caractères min)',
                  prefixIcon: Icon(LucideIcons.lock),
                ),
                obscureText: true,
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
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _createUser,
                icon: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(LucideIcons.userPlus),
                label: Text(_isLoading ? 'Création...' : 'Ajouter l\'utilisateur'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
