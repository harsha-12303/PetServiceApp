import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/datasources/session_local_data_source.dart';
import '../../../domain/repositories/admin_module_repository.dart';
import '../../../domain/repositories/catalog_repository.dart';
import '../../../domain/repositories/cart_quantity_store.dart';
import '../../home/views/petwork_home_screen.dart';
import '../viewmodels/login_view_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.viewModel,
    required this.catalogRepository,
    required this.cartQuantityStore,
    this.adminModuleRepository,
    this.sessionCache,
    this.loginScreenBuilder,
  });

  final LoginViewModel viewModel;
  final CatalogRepository catalogRepository;
  final CartQuantityStore cartQuantityStore;
  final AdminModuleRepository? adminModuleRepository;
  final SessionLocalDataSource? sessionCache;
  final Widget Function()? loginScreenBuilder;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_refresh);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final session = await widget.viewModel.signIn(
      _emailController.text.trim(),
      _passwordController.text,
    );
    if (!mounted) return;
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(widget.viewModel.errorMessage ?? 'Unable to sign in.')),
      );
      return;
    }
    await widget.sessionCache?.save(session);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PetWorkHomeScreen(
          session: session,
          catalogRepository: widget.catalogRepository,
          cartQuantityStore: widget.cartQuantityStore,
          adminModuleRepository: widget.adminModuleRepository,
          onLogout: widget.sessionCache?.clear,
          loginScreenBuilder: widget.loginScreenBuilder,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _Brand(),
                      const SizedBox(height: 32),
                      Text('Welcome back',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      const Text('Sign in to manage your pet care services.',
                          style: TextStyle(color: AppColors.textMuted)),
                      const SizedBox(height: 32),
                      _Input(
                        controller: _emailController,
                        label: 'Email address',
                        hint: 'you@example.com',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (email.isEmpty) {
                            return 'Enter your email address';
                          }
                          if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                              .hasMatch(email)) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      _Input(
                        controller: _passwordController,
                        label: 'Password',
                        hint: 'Enter your password',
                        icon: Icons.lock_outline_rounded,
                        obscureText: _obscurePassword,
                        onSubmitted: (_) => _submit(),
                        suffix: IconButton(
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                          icon: Icon(_obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                        ),
                        validator: (value) => (value ?? '').isEmpty
                            ? 'Enter your password'
                            : null,
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        height: 54,
                        child: FilledButton(
                          onPressed:
                              widget.viewModel.isLoading ? null : _submit,
                          style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary),
                          child: widget.viewModel.isLoading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Text('Sign in'),
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
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.primaryTint,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.pets_rounded, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        const Flexible(
          child: Text('PetCareServices',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ),
      ]);
}

class _Input extends StatelessWidget {
  const _Input(
      {required this.controller,
      required this.label,
      required this.hint,
      required this.icon,
      required this.validator,
      this.keyboardType,
      this.obscureText = false,
      this.suffix,
      this.onSubmitted});
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? Function(String?) validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: validator,
          onFieldSubmitted: onSubmitted,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon),
            suffixIcon: suffix,
          ),
        ),
      ]);
}
