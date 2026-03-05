import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:food/pages/register/register.dart';
import 'package:food/pages/reset/reset.dart';
import 'package:food/services/auth_service.dart';
import 'package:food/widget/custom_dialog.dart';
import 'package:food/main.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin<LoginPage> {
  bool isLoading = false;
  bool _isGoogleLoading = false;

  late final AnimationController loginButtonController;
  late final Animation<double> buttonSqueezeAnimation;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final passwordFocusNode = FocusNode();

  bool _obscureText = true;
  bool isEmailValid = true;
  bool isPasswordValid = true;

  final RegExp _emailRegex = RegExp(
    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
    caseSensitive: false,
    multiLine: false,
  );

  void _validateEmail() {
    setState(() {
      final email = _emailController.text.trim();
      isEmailValid = _emailRegex.hasMatch(email);
    });
  }

  void _validatePassword() {
    setState(() {
      final password = _passwordController.text;
      isPasswordValid = password.length >= 6;
    });
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    _emailController.addListener(_validateEmail);
    _passwordController.addListener(_validatePassword);

    loginButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    buttonSqueezeAnimation = Tween(
      begin: 320.0,
      end: 70.0,
    ).animate(
      CurvedAnimation(
        parent: loginButtonController,
        curve: const Interval(0.0, 0.250),
      ),
    );
  }

  @override
  void dispose() {
    passwordFocusNode.dispose();
    loginButtonController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final User? user = await authService.signInWithGoogle();

      if (!mounted) return;

      if (user != null) {
        // Auth state change triggers AuthCheck to show MainWrapper
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google Sign-In cancelled.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Google Sign-In failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/bg.jpg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withAlpha(0xBF),
              BlendMode.darken,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            Container(
              margin:
                  EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              color: Colors.transparent,
              width: double.infinity,
              height: kToolbarHeight,
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: emailTextField(),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: passwordTextField(),
                      ),
                      const SizedBox(height: 32.0),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: loginButton(),
                      ),
                      const SizedBox(height: 16.0),
                      _buildDivider(),
                      const SizedBox(height: 16.0),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: _buildGoogleSignInButton(),
                      ),
                      const SizedBox(height: 24.0),
                      Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: needAnAccount(),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: forgotPassword(),
                      ),
                    ],
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.white38)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.0),
            child: Text('OR', style: TextStyle(color: Colors.white54)),
          ),
          Expanded(child: Divider(color: Colors.white38)),
        ],
      ),
    );
  }

  Widget _buildGoogleSignInButton() {
    return SizedBox(
      width: 320,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _isGoogleLoading ? null : _signInWithGoogle,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.0),
          ),
        ),
        icon: _isGoogleLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Image.network(
                'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                height: 20,
                width: 20,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.g_mobiledata, size: 24),
              ),
        label: const Text('Sign in with Google'),
      ),
    );
  }

  Widget emailTextField() {
    return TextField(
      controller: _emailController,
      autocorrect: true,
      decoration: const InputDecoration(
        prefixIcon: Padding(
          padding: EdgeInsetsDirectional.only(end: 8.0),
          child: Icon(Icons.email, color: Colors.white),
        ),
        labelText: 'Email',
        labelStyle: TextStyle(color: Colors.white),
      ),
      keyboardType: TextInputType.emailAddress,
      maxLines: 1,
      style: const TextStyle(fontSize: 16.0, color: Colors.white),
      textInputAction: TextInputAction.next,
      autofocus: false,
      onSubmitted: (_) {
        FocusScope.of(context).requestFocus(passwordFocusNode);
      },
    );
  }

  Widget passwordTextField() {
    Color labelColor = isPasswordValid ? Colors.white : Colors.red;
    Color iconColor = isPasswordValid ? Colors.white : Colors.red;
    return TextField(
      controller: _passwordController,
      autocorrect: true,
      obscureText: _obscureText,
      decoration: InputDecoration(
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscureText = !_obscureText),
          icon: Icon(
            _obscureText ? Icons.visibility_off : Icons.visibility,
            color: Colors.white,
          ),
          iconSize: 18.0,
        ),
        labelText: 'Password',
        labelStyle: TextStyle(color: labelColor),
        prefixIcon: Padding(
          padding: const EdgeInsetsDirectional.only(end: 8.0),
          child: Icon(Icons.lock, color: iconColor),
        ),
      ),
      keyboardType: TextInputType.text,
      maxLines: 1,
      style: const TextStyle(fontSize: 16.0, color: Colors.white),
      onSubmitted: (_) {
        FocusScope.of(context).unfocus();
      },
      textInputAction: TextInputAction.done,
      focusNode: passwordFocusNode,
    );
  }

  Widget loginButton() {
    return AnimatedBuilder(
      animation: buttonSqueezeAnimation,
      builder: (context, child) {
        final value = buttonSqueezeAnimation.value;
        return SizedBox(
          width: value,
          height: 60.0,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24.0),
              border: Border.all(color: Colors.greenAccent, width: 2.0),
            ),
            child: Material(
              elevation: 5.0,
              clipBehavior: Clip.antiAlias,
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(24.0),
              child: !isLoading
                  ? child
                  : const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.0,
                        backgroundColor: Colors.green,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
            ),
          ),
        );
      },
      child: MaterialButton(
        onPressed: () {
          FocusScope.of(context).unfocus();
          setState(() => isLoading = true);
          _login();
        },
        color: Colors.transparent,
        splashColor:
            Theme.of(context).colorScheme.secondary.withOpacity(0.5),
        child: const Text(
          'LOGIN',
          style: TextStyle(color: Colors.white, fontSize: 16.0),
        ),
      ),
    );
  }

  Widget needAnAccount() {
    return TextButton(
      onPressed: () {
        Navigator.pushReplacement(
          context,
          CupertinoPageRoute(builder: (context) => const RegisterPage()),
        );
      },
      child: const Text(
        "Don't have an account? Sign up",
        style: TextStyle(
          color: Colors.white70,
          fontStyle: FontStyle.italic,
          fontSize: 14.0,
        ),
      ),
    );
  }

  Widget forgotPassword() {
    return TextButton(
      onPressed: () {
        Navigator.pushReplacement(
          context,
          CupertinoPageRoute(builder: (context) => const ResetPage()),
        );
      },
      child: const Text(
        'Forgot password?',
        style: TextStyle(
          color: Colors.white70,
          fontStyle: FontStyle.italic,
          fontSize: 14.0,
        ),
      ),
    );
  }

  void _login() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    String email = _emailController.text.trim();
    String password = _passwordController.text;

    if (isEmailValid && isPasswordValid) {
      try {
        await authService.login(email, password);

        if (authService.isLoggedIn) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Login successful.'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MainWrapper()),
            );
          }
        } else {
          isLoading = false;
          if (mounted) {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return const CustomAlertDialog(
                  title: 'Error',
                  message: 'Login failed.',
                );
              },
            );
          }
        }
      } catch (e) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return const CustomAlertDialog(
                title: 'Error',
                message: 'Login failed.',
              );
            },
          );
        }
      } finally {
        if (mounted) setState(() => isLoading = false);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please Check Credentials.'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => isLoading = false);
    }
  }
}
