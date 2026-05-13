import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/auth_video_background.dart';
import '../widgets/password_requirements.dart';

class EmailSignUpScreen extends StatefulWidget {
  const EmailSignUpScreen({super.key});

  @override
  State<EmailSignUpScreen> createState() => _EmailSignUpScreenState();
}

class _EmailSignUpScreenState extends State<EmailSignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  
  bool _obscure = true;
  bool _loading = false;
  bool _usernameChecking = false;
  bool _usernameAvailable = false;
  String? _usernameError;

  static const _cardHotPink     = Color(0xFFFF3399);
  static const _cardNeonPurple  = Color(0xFF9D50BB);

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _checkUsername(String val) async {
    if (val.isEmpty) {
      setState(() { _usernameChecking = false; _usernameError = null; _usernameAvailable = false; });
      return;
    }
    setState(() { _usernameChecking = true; _usernameError = null; _usernameAvailable = false; });
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() { _usernameChecking = false; _usernameAvailable = true; });
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account created! (Demo mode)')),
    );
  }

  Widget _buildMinimalField({
    required String label,
    required TextEditingController controller,
    required double scaledFont,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction? textInputAction,
    VoidCallback? onSubmitted,
    bool autofocus = false,
    void Function(String)? onChanged,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: (_) => onSubmitted?.call(),
      autofocus: autofocus,
      onChanged: onChanged,
      validator: validator,
      style: TextStyle(
        fontFamily: 'Circular',
        fontSize: scaledFont,
        fontWeight: FontWeight.w600,
        color: label.toLowerCase().contains('password') ? _cardHotPink : Colors.white,
      ),
      cursorColor: _cardHotPink,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontFamily: 'Circular', fontSize: scaledFont * 0.85,
          fontWeight: FontWeight.w400, color: Colors.white70,
        ),
        floatingLabelStyle: TextStyle(
          fontFamily: 'Circular', fontSize: scaledFont * 0.7,
          fontWeight: FontWeight.w700, color: _cardHotPink,
        ),
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24, width: 1.5)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _cardHotPink, width: 2.5)),
        errorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.redAccent, width: 1.5)),
        focusedErrorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.redAccent, width: 2.5)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    final hPad = w * 0.08;
    final headerFont = (w * 0.1).clamp(28.0, 44.0);
    final subFont = (w * 0.042).clamp(14.0, 18.0);
    final fieldFont = (w * 0.052).clamp(16.0, 22.0);
    final btnHeight = (h * 0.065).clamp(48.0, 56.0);

    return AuthVideoBackground(
      overlayOpacity: 0.4,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 20 : 0),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: h * 0.05),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Create your\naccount.",
                            style: TextStyle(
                              fontFamily: 'Circular',
                              fontSize: headerFont,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.1,
                              letterSpacing: -1.0,
                            ),
                          ),
                          SizedBox(height: h * 0.012),
                          Text(
                            "Set up your profile to start matching.",
                            style: TextStyle(
                              fontFamily: 'Circular',
                              fontSize: subFont,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                            ),
                          ),
                          SizedBox(height: h * 0.045),
    
                          _buildMinimalField(
                            label: 'Username',
                            controller: _usernameCtrl,
                            scaledFont: fieldFont,
                            textInputAction: TextInputAction.next,
                            autofocus: false,
                            onChanged: _checkUsername,
                          ),
                          if (_usernameChecking)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(children: const [
                                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70)),
                                SizedBox(width: 8),
                                Text('Checking...', style: TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'Circular')),
                              ]),
                            ),
                          if (_usernameError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(_usernameError!, style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontFamily: 'Circular')),
                            ),
                          if (_usernameAvailable && _usernameCtrl.text.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: const Text('✓ Available', style: TextStyle(color: Colors.greenAccent, fontSize: 13, fontFamily: 'Circular', fontWeight: FontWeight.w600)),
                            ),
                          SizedBox(height: h * 0.03),
    
                          _buildMinimalField(
                            label: 'Email address',
                            controller: _emailCtrl,
                            scaledFont: fieldFont,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Required';
                              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) return 'Invalid email';
                              return null;
                            },
                          ),
                          SizedBox(height: h * 0.03),
    
                          _buildMinimalField(
                            label: 'Password',
                            controller: _passwordCtrl,
                            scaledFont: fieldFont,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.done,
                            onSubmitted: _submit,
                            onChanged: (_) => setState(() {}),
                            suffixIcon: IconButton(
                              icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: _cardHotPink),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                            validator: (v) {
                              if (v == null || v.length < 8) return 'At least 8 characters';
                              if (!v.contains(RegExp(r'[A-Z]'))) return 'Add an uppercase letter';
                              if (!v.contains(RegExp(r'[0-9]'))) return 'Add a number';
                              if (!v.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) return 'Add a special character';
                              return null;
                            },
                          ),
                          SizedBox(height: h * 0.015),
                          
                          PasswordRequirements(password: _passwordCtrl.text),
                          SizedBox(height: h * 0.04),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
                
                AnimatedPadding(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: btnHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(btnHeight / 2),
                        gradient: const LinearGradient(colors: [_cardHotPink, _cardNeonPurple]),
                        boxShadow: [
                          BoxShadow(color: _cardHotPink.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(btnHeight / 2)),
                        ),
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : Text('Continue', style: TextStyle(fontFamily: 'Circular', fontSize: subFont, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
