import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_logo_header.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/role_toggle.dart';
import 'login_screen.dart';
import '../customer/customer_home_screen.dart';
import '../owner/owner_dashboard_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool _isCustomer = true;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onRegister() {
    final state = context.read<AppState>();
    final error = state.register(
      name: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text,
      isOwner: !_isCustomer,
      address: _addressController.text,
      phone: _phoneController.text,
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

  void _goToLogin() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
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
                  _nameController.clear();
                  _emailController.clear();
                  _passwordController.clear();
                  _addressController.clear();
                  _phoneController.clear();
                }),
              ),
              const SizedBox(height: 24),

              CustomTextField(
                label: _isCustomer ? 'Full Name' : 'Restaurant / Owner Name',
                hintText: _isCustomer ? 'John Doe' : 'Restoran Nasi Kukus Luqman',
                controller: _nameController,
              ),
              const SizedBox(height: 16),

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
              const SizedBox(height: 16),

              if (!_isCustomer) ...[
                CustomTextField(
                  label: 'Restaurant Address',
                  hintText: 'e.g. Jln Tok Guru, Kota Bharu, Kelantan',
                  controller: _addressController,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'Phone Number',
                  hintText: 'e.g. 012-345 6789',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
              ],

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _onRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.black,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(
                    _isCustomer ? 'Register as Customer' : 'Register as Owner',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              GestureDetector(
                onTap: _goToLogin,
                child: const Text(
                  'Already have an account? Sign in',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textDark),
                ),
              ),

              if (_isCustomer) ...[
                const SizedBox(height: 20),
                const Row(children: [
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