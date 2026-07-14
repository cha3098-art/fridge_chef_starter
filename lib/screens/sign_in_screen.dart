import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../services/auth_service.dart';
import '../services/locale_store.dart';
import '../theme/app_theme.dart';
import '../widgets/fridge_mascot.dart';
import '../widgets/language_toggle.dart';
import 'sign_up_screen.dart';

/// 로그인 화면 — Supabase Auth(이메일/비밀번호)로 로그인한다.
/// 로그인에 성공하면 AuthGate가 세션 변경을 감지해 자동으로 냉장고 화면으로 넘어간다.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await AuthService.instance.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // 로그인 성공 시 main.dart의 AuthGate가 세션 스트림을 듣고 자동 전환한다
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('로그인에 실패했어요: $e', 'Sign-in failed: $e'))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocaleStore.instance,
      builder: (context, _) => Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        elevation: 0,
        title: Text(tr('로그인', 'Sign In')),
        actions: const [
          Padding(padding: EdgeInsets.only(right: 12), child: LanguageToggle()),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.lg),
        children: [
          const Center(child: FridgeMascot(size: 108)),
          const SizedBox(height: AppSpacing.lg),
          Text(
            tr('냉장고 고민 끝!', 'No more fridge worries!'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 26, color: AppColors.ink, height: 1.2),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            tr('내 재료로 맞춤 레시피, 냉장고 셰프', 'Custom recipes from what you have'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.inkSoft),
          ),
          const SizedBox(height: AppSpacing.xl),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: cardDecoration(),
            child: Column(
              children: [
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(labelText: tr('이메일', 'Email')),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(labelText: tr('비밀번호', 'Password')),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(tr('로그인', 'Sign In')),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SignUpScreen()),
              ),
              child: Text(tr('아직 계정이 없나요? 회원가입', "Don't have an account? Sign up")),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
