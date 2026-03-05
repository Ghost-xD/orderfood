import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:food/main.dart';
import 'package:food/pages/login/login_page.dart';
import 'package:food/services/auth_service.dart';
import 'package:food/widget/custom_dialog.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> with SingleTickerProviderStateMixin<RegisterPage> {
  bool isLoading = false;
  bool _isGoogleLoading = false;
  late final AnimationController registerButtonController;
  late final Animation<double> buttonSqueezeAnimation;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final passwordFocusNode = FocusNode();
  final confirmPasswordFocusNode = FocusNode();

  bool _obscureText = true;

  bool isEmailValid = true;
  bool isPasswordValid = true;
  bool isPasswordMatched = true;

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
      final confirmPassword = _confirmPasswordController.text;
      if (password.length >= 6) {
        isPasswordValid = true;
      } else {
        isPasswordValid = false;
      }

      isPasswordMatched = password == confirmPassword;
    });
  }

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    _emailController.addListener(_validateEmail);
    _passwordController.addListener(_validatePassword);
    _confirmPasswordController.addListener(_validatePassword);

    registerButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    buttonSqueezeAnimation = Tween(
      begin: 320.0,
      end: 70.0,
    ).animate(
      CurvedAnimation(
        parent: registerButtonController,
        curve: const Interval(
          0.0,
          0.250,
        ),
      ),
    );
  }

  @override
  void dispose() {
    passwordFocusNode.dispose();
    confirmPasswordFocusNode.dispose();
    registerButtonController.dispose();
    super.dispose();
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
              margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
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
                        child: passwordTextField(_passwordController, 'Password', passwordFocusNode),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: confirmpasswordTextField(_confirmPasswordController, 'Confirm Password', confirmPasswordFocusNode),
                      ),
                      const SizedBox(height: 32.0),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: registerButton(),
                      ),
                      const SizedBox(height: 32.0),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: backButton(),
                      ),
                      signInWithGoogle(),
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

  Widget emailTextField() {
    return TextField(
      controller: _emailController,
      autocorrect: true,
      decoration: const InputDecoration(
        prefixIcon: Padding(
          padding: EdgeInsetsDirectional.only(end: 8.0),
          child: Icon(Icons.email, color: Colors.white,),
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

  Widget passwordTextField(TextEditingController controller, String text, FocusNode node) {
    return TextField(
      controller: controller,
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
        labelText: text,
        labelStyle: const TextStyle(color: Colors.white),
        prefixIcon: const Padding(
          padding: EdgeInsetsDirectional.only(end: 8.0),
          child: Icon(Icons.lock, color: Colors.white),
        ),
      ),
      keyboardType: TextInputType.text,
      maxLines: 1,
      style: const TextStyle(fontSize: 16.0, color: Colors.white),
      onSubmitted: (_) {
        FocusScope.of(context).requestFocus(confirmPasswordFocusNode);
      },
      textInputAction: TextInputAction.done,
      focusNode: node
    );
  }

  Widget confirmpasswordTextField(TextEditingController controller, String text, FocusNode node) {
    return TextField(
      controller: controller,
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
        labelText: text,
        labelStyle: const TextStyle(color: Colors.white),
        prefixIcon: const Padding(
          padding: EdgeInsetsDirectional.only(end: 8.0),
          child: Icon(Icons.lock, color: Colors.white),
        ),
      ),
      keyboardType: TextInputType.text,
      maxLines: 1,
      style: const TextStyle(fontSize: 16.0, color: Colors.white),
      onSubmitted: (_) {
        FocusScope.of(context).unfocus();
      },
      textInputAction: TextInputAction.done,
      focusNode: node
    );
  }

  Widget registerButton() {
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
              border: Border.all(
                color: Colors.greenAccent,
                width: 2.0,
              ),
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
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
            ),
          ),
        );
      },
      child: MaterialButton(
        onPressed: () {
          FocusScope.of(context).unfocus();
          setState(() {
            isLoading = true;
          });
          _register();
        },
        color: Colors.transparent,
        splashColor: Theme.of(context).colorScheme.secondary.withOpacity(0.5),
        child: const Text(
          'Register',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.0,
          ),
        ),
      ),
    );
  }

  Widget backButton() {
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
              border: Border.all(
                color: Colors.deepOrangeAccent,
                width: 2.0,
              ),
            ),
            child: Material(
            elevation: 5.0,
            clipBehavior: Clip.antiAlias,
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(24.0),
            child: child
          ),
          ),
        );
      },
      child: MaterialButton(
        onPressed: () {
          Navigator.pushReplacement(context,CupertinoPageRoute(builder: (context) => const LoginPage()));
        },
        color: Colors.transparent,
        splashColor: Theme.of(context).colorScheme.secondary.withOpacity(0.5),
        child: const Text(
          'Back to Login',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.0,
          ),
        ),
      ),
    );
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final User? user = await authService.signInWithGoogle();

      if (!mounted) return;

      if (user != null) {
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

  Widget signInWithGoogle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: SizedBox(
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
              : const Icon(Icons.g_mobiledata, size: 24),
          label: const Text('Sign in with Google'),
        ),
      ),
    );
  }

  void _register() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (isEmailValid && isPasswordValid && isPasswordMatched){
      Map<String, dynamic> userData = {
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'confirmpassword': _confirmPasswordController.text
      };

      try {
        await authService.registeruser(userData);

        if (authService.isLoggedIn) {
          if(mounted){
            if(mounted){
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Registration Successful.'), backgroundColor: Colors.green,),
              );
            }
            Navigator.push(context,MaterialPageRoute(builder: (context) => const MainWrapper()),);
          }
        } else {
          isLoading = false;
          if(mounted){
            showDialog(
                context: context,
                builder: (BuildContext context) {
                  return const CustomAlertDialog(
                    title: 'Error',
                    message: 'Registration failed.',
                  );
                },
              );
          }
        }
      } catch (e) {
        isLoading = false;
        var errorMessage = e.toString();
        if (errorMessage.contains('Invalid password string')) {
          errorMessage = 'Invalid password: Password must be at least 6 characters long.';
        }
        if(mounted){
          showDialog(
                context: context,
                builder: (BuildContext context) {
                  return CustomAlertDialog(
                    title: 'Error',
                    message: errorMessage,
                  );
                },
              );
        }
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    }
    else{
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please Check Credentials.'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        isLoading = false;
      });
    }
    
  }

}
