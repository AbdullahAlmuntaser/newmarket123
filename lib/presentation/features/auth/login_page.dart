import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supermarket/core/auth/auth_provider.dart';
import 'package:supermarket/l10n/app_localizations.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController(text: 'System Admin');
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _isCheckingSetup = true;
  bool _needsInitialSetup = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkInitialSetup());
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _checkInitialSetup() async {
    try {
      final hasUsers = await context.read<AuthProvider>().hasUsers();
      if (!mounted) return;
      setState(() {
        _needsInitialSetup = !hasUsers;
        _isCheckingSetup = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCheckingSetup = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في فحص التهيئة: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(32),
            child: _isCheckingSetup
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.account_balance,
                        size: 80,
                        color: Colors.teal,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        l10n.accountingSystem,
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 32),
                      if (_needsInitialSetup)
                        _buildInitialSetupForm()
                      else
                        _buildLoginForm(l10n),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _usernameController,
          decoration: InputDecoration(
            labelText: l10n.username,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: l10n.password,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isLoading ? null : _login,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : Text(l10n.loginButton),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.loginHint,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildInitialSetupForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'تهيئة المسؤول الأول',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'لا يوجد مستخدمون بعد. أنشئ حساب مسؤول بكلمة مرور قوية للبدء.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _fullNameController,
          decoration: const InputDecoration(
            labelText: 'اسم المسؤول',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _usernameController,
          decoration: const InputDecoration(
            labelText: 'اسم المستخدم',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'كلمة المرور',
            helperText: '8 أحرف على الأقل',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmPasswordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'تأكيد كلمة المرور',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isLoading ? null : _createInitialAdmin,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('إنشاء المسؤول والدخول'),
        ),
      ],
    );
  }

  Future<void> _login() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();

    try {
      final success = await auth.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          context.go('/');
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.invalidCredentials)));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _createInitialAdmin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (username.isEmpty) {
      _showSetupError('يرجى إدخال اسم المستخدم');
      return;
    }
    if (password.length < 8) {
      _showSetupError('كلمة المرور يجب أن تكون 8 أحرف على الأقل');
      return;
    }
    if (password != confirmPassword) {
      _showSetupError('كلمتا المرور غير متطابقتين');
      return;
    }

    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();

    try {
      await auth.createInitialAdmin(
        username: username,
        password: password,
        fullName: _fullNameController.text,
      );
      final success = await auth.login(username, password);

      if (!mounted) return;
      setState(() => _isLoading = false);
      if (success) {
        context.go('/');
      } else {
        _showSetupError('تم إنشاء المسؤول، لكن فشل تسجيل الدخول التلقائي');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSetupError('خطأ: $e');
    }
  }

  void _showSetupError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
