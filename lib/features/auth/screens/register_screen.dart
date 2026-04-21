import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/mock_auth_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/age_validator.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  DateTime? _selectedDate;
  bool _isLoading = false;

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      if (!AgeValidator.isAdult(picked)) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
            content: Text('Uygulamayı kullanmak için 18 yaşından büyük olmalısınız.'),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => _selectedDate = null);
        return;
      }
      setState(() => _selectedDate = picked);
    }
  }

  void _register() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lütfen tüm alanları doldurun.'), backgroundColor: AppColors.error),
      );
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lütfen doğum tarihinizi seçin.'), backgroundColor: AppColors.error),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    final success = await context.read<MockAuthService>().register(
      _emailController.text.trim(),
      _passwordController.text,
      _selectedDate!,
    );
    
    if (!mounted) return;
    setState(() => _isLoading = false);
    
    if (success) {
      Navigator.pop(context); // Ana sayfa Provider üzerinden _isAuthenticated=true olunca otomatik geçer
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kayıt başarısız. Lütfen tekrar deneyin.'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: const BackButton(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.5,
            colors: [AppColors.surface, AppColors.background],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.person_add_alt_1, size: 60, color: AppColors.secondary),
                  const SizedBox(height: 16),
                  Text(
                    'Aramıza Katıl',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'E-posta',
                      prefixIcon: Icon(Icons.email_outlined, color: AppColors.textSecondary),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Şifre',
                      prefixIcon: Icon(Icons.lock_outline, color: AppColors.textSecondary),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.cake_outlined, color: AppColors.textSecondary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedDate == null 
                                ? 'Doğum Tarihi (18+)' 
                                : DateFormat('dd/MM/yyyy').format(_selectedDate!),
                              style: TextStyle(
                                color: _selectedDate == null ? AppColors.textSecondary : Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (_selectedDate != null)
                             Icon(Icons.check_circle, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    child: _isLoading 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('KAYIT OL'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
