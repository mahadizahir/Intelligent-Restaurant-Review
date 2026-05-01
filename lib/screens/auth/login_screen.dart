import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_logo_header.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/role_toggle.dart';
import 'register_screen.dart';
import '../customer/customer_home_screen.dart';
import '../owner/owner_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isCustomer = true;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onSignIn() {
    final state = context.read<AppState>();
    final error = state.login(
      email: _emailController.text,
      password: _passwordController.text,
      isOwner: !_isCustomer,
    );
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _isCustomer ? const CustomerHomeScreen() : const OwnerDashboardScreen(),
      ),
    );
  }

  void _goToRegister() {
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
  }

  void _browseAsGuest() {
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const CustomerHomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              const SizedBox(height: 24),
              const AppLogoHeader(),
              const SizedBox(height: 28),

              RoleToggle(
                isCustomer: _isCustomer,
                onToggle: (val) => setState(() {
                  _isCustomer = val;
                  _emailController.clear();
                  _passwordController.clear();
                }),
              ),
              const SizedBox(height: 24),

              CustomTextField(
                label: 'Email',
                hintText: _isCustomer ? 'customer@example.com' : 'owner@restaurant.com',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              CustomTextField(
                label: 'Password',
                hintText: '••••••••',
                obscureText: true,
                controller: _passwordController,
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _onSignIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.black,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(
                    _isCustomer ? 'Sign In as Customer' : 'Sign In as Owner',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              GestureDetector(
                onTap: _goToRegister,
                child: const Text(
                  "Don't have an account? Register",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textDark),
                ),
              ),

              if (_isCustomer) ...[
                const SizedBox(height: 20),
                Row(children: const [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('OR', style: TextStyle(color: AppColors.grey, fontSize: 13)),
                  ),
                  Expanded(child: Divider()),
                ]),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _browseAsGuest,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.lightGrey),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Browse as Guest',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark, fontSize: 15)),
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}