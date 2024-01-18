// create login page
import 'app.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'reset_pass.dart';
import 'signup.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

// ログインページの作成
class _LoginPageState extends State<LoginPage> {
  // メールアドレスとパスワードの入力値
  String _email = "";
  String _password = "";
  // パスワードの表示
  bool _isHidepass = true;
  // ログインに関するエラーメッセージ
  String _errorMessage = "";
  // ログインに関するエラーが発生したかどうか
  bool _hasError = false;
  // ログイン中かどうか
  bool _isLoading = false;

  // Googleアカウントでログインするためのコード
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  _save(user) async {
    // ドキュメントがあるか確認
    final doc = await FirebaseFirestore.instance
        .collection('USERS')
        .doc(user?.uid)
        .get();
    if (!doc.exists) {
      // ドキュメントがない場合は新規作成
      await FirebaseFirestore.instance.collection('USERS').doc(user?.uid).set({
        'uid': user?.uid,
        'email': user?.email,
        'currentGroupId': "",
        'currentSubgroupId': [],
        'location': null,
        'name': "",
      });
    }
  }

  // ログイン処理
  _login() async {
    // ログイン中であることを示す
    setState(() {
      _isLoading = true;
    });
    try {
      // メールアドレスとパスワードでログイン
      final user = (await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email,
        password: _password,
      ))
          .user;
      setState(() {
        _isLoading = false;
      });
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomePage(user: user),
        ),
      );
    } catch (e) {
      // ログインに失敗したらエラーメッセージを表示
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
      return;
    }
  }

  // Googleアカウントでのログイン処理
  _signInWithGoogle() async {
    // ログイン中であることを示す
    setState(() {
      _isLoading = true;
    });
    User? user;
    try {
      if (kIsWeb) {
        final GoogleAuthProvider googleAuthProvider = GoogleAuthProvider();
        final UserCredential userCredential =
            await _auth.signInWithPopup(googleAuthProvider);
        user = userCredential.user;
        _save(user);
      } else {
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser != null) {
          // Googleアカウントでログインするための認証情報を取得
          final GoogleSignInAuthentication googleAuth =
              await googleUser.authentication;
          // FirebaseにGoogleアカウントでログインするための認証情報を渡す
          final credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );

          // Firebaseに認証情報を渡してログインする
          final UserCredential userCredential =
              await _auth.signInWithCredential(credential);

          user = userCredential.user;
          _save(user);
        }
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomePage(user: user),
        ),
      );
    } catch (e) {
      // ログインに失敗したらエラーメッセージを表示
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
    } finally {
      // ログインが完了したらローディングを解除
      setState(() {
        _isLoading = false;
      });
    }
  }

  // パスワード再設定処理

  // ログインページの作成
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ログイン"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // メールアドレスの入力
            TextField(
              decoration: InputDecoration(
                labelText: "メールアドレス",
                hintText: "メールアドレスを入力してください",
                errorText: _hasError ? _errorMessage : null,
              ),
              onChanged: (value) {
                setState(() {
                  _email = value;
                });
              },
            ),
            // パスワードの入力
            Row(children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                      labelText: "パスワード",
                      hintText: "パスワードを入力してください",
                      errorText: _hasError ? _errorMessage : null,
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _isHidepass = !_isHidepass;
                          });
                        },
                        icon: _isHidepass
                            ? const Icon(Icons.visibility)
                            : const Icon(Icons.visibility_off),
                      )),
                  obscureText: _isHidepass,
                  onChanged: (value) {
                    setState(() {
                      _password = value;
                    });
                  },
                ),
              )
            ]),
            const SizedBox(height: 16),
            TextButton(
              child: const Text(
                "パスワードを忘れましたか?",
                style: TextStyle(color: Colors.blue),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ResetPassPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _login,
                child: const Text("ログイン"),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    child: const Text("Googleでログイン"))),
            // ログインボタン
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              const Text("まだアカウントを持っていませんか?"),
              const SizedBox(width: 8),
              TextButton(
                child: const Text(
                  "登録する",
                  style: TextStyle(color: Colors.blue),
                ),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SigninPage(),
                    ),
                  );
                },
              )
            ]),
          ],
        ),
      ),
    );
  }
}
