import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/datasources/saved_credentials_store.dart';
import '../../../data/datasources/session_local_data_source.dart';
import '../../../domain/repositories/admin_module_repository.dart';
import '../../../domain/repositories/catalog_repository.dart';
import '../../../domain/repositories/cart_quantity_store.dart';
import '../../home/views/petwork_home_screen.dart';
import '../viewmodels/login_view_model.dart';
import '../../shared/widgets/app_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.viewModel,
    required this.catalogRepository,
    required this.cartQuantityStore,
    this.adminModuleRepository,
    this.sessionCache,
    this.loginScreenBuilder,
    this.credentialsStore,
  });

  /// Remembers the last successful login ("Remember me").
  final CredentialsStore? credentialsStore;

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
  bool _rememberMe = true;

  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_refresh);
    _fillSavedLogin();
  }

  /// Pre-fills the form with the last login the user chose to remember.
  Future<void> _fillSavedLogin() async {
    final saved = await widget.credentialsStore?.read();
    if (saved == null || !mounted) return;
    // Don't overwrite anything the user already started typing.
    if (_emailController.text.isEmpty) _emailController.text = saved.email;
    if (_passwordController.text.isEmpty) {
      _passwordController.text = saved.password;
    }
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
    final store = widget.credentialsStore;
    if (_rememberMe) {
      await store?.save(_emailController.text.trim(), _passwordController.text);
    } else {
      await store?.clear();
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
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_navy, AppColors.primary],
            ),
          ),
          child: Stack(children: [
            // Soft decorative circles.
            const Positioned(top: -90, right: -70, child: _Glow(size: 260)),
            const Positioned(bottom: -110, left: -80, child: _Glow(size: 300)),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(children: [
                      const _Brand(),
                      const SizedBox(height: 24),
                      _card(),
                      const SizedBox(height: 20),
                      Text(
                        '© ${DateTime.now().year} PetWork',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12.5,
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ]),
        ),
      );

  Widget _card() => Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Welcome back',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sign in to manage your pet care services.',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 14.5),
                ),
                const SizedBox(height: 26),
                _Input(
                  controller: _emailController,
                  label: 'Email address',
                  hint: 'you@example.com',
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) return 'Enter your email address';
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                        .hasMatch(email)) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _Input(
                  controller: _passwordController,
                  label: 'Password',
                  hint: 'Enter your password',
                  icon: Icons.lock_outline_rounded,
                  obscureText: _obscurePassword,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _submit(),
                  suffix: IconButton(
                    tooltip:
                        _obscurePassword ? 'Show password' : 'Hide password',
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(_obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                  ),
                  validator: (value) =>
                      (value ?? '').isEmpty ? 'Enter your password' : null,
                ),
                const SizedBox(height: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _rememberMe = !_rememberMe),
                  child: Row(children: [
                    Checkbox(
                      value: _rememberMe,
                      onChanged: (value) =>
                          setState(() => _rememberMe = value ?? false),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5)),
                    ),
                    const Text('Remember me',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.text)),
                  ]),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: widget.viewModel.isLoading ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    child: widget.viewModel.isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Sign in'),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

/// The logo's navy, used for the background gradient.
const _navy = Color(0xFF192A3E);

class _Glow extends StatelessWidget {
  const _Glow({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.05),
        ),
      );
}

/// Small logo with the product name, above the sign-in card.
class _Brand extends StatelessWidget {
  const _Brand();
  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
            ),
            child: const AppLogo(size: 40),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('PetWork',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800)),
              Text('Admin console',
                  style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 13)),
            ],
          ),
        ],
      );
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
      this.onSubmitted,
      this.autofillHints});
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? Function(String?) validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: AppColors.text)),
      const SizedBox(height: 8),
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        validator: validator,
        onFieldSubmitted: onSubmitted,
        autofillHints: autofillHints,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: AppColors.primarySoft,
          prefixIcon: Icon(icon, color: AppColors.primary),
          suffixIcon: suffix,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          enabledBorder: border(Colors.transparent),
          focusedBorder: border(AppColors.primary, 1.6),
          errorBorder: border(const Color(0xFFC0392B)),
          focusedErrorBorder: border(const Color(0xFFC0392B), 1.6),
        ),
      ),
    ]);
  }
}
