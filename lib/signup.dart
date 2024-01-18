import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'login.dart';
import 'app.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class SigninPage extends StatefulWidget {
  const SigninPage({super.key});

  @override
  _SigninPageState createState() => _SigninPageState();
}

// サインインページの作成
class _SigninPageState extends State<SigninPage> {
  // メールアドレスとパスワードの入力値
  String _email = "";
  String _password = "";
  String _checkpassword = "";
  // パスワードを隠すか
  bool _isHidepass = true;
  bool _isHidecheckpass = true;
  // サインインに関するエラーメッセージ
  String _errorMessage = "";
  // サインインに関するエラーが発生したかどうか
  bool _hasError = false;
  // サインイン中かどうか
  bool _isLoading = false;
  // firestoreのドキュメントID
  String _id = "";
  User? user;

  // Googleアカウントでログインするためのコード
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  _save(user) async {
    if (_id != "") {
      // ドキュメントがある場合はデータを更新
      await FirebaseFirestore.instance.collection('USERS').doc(_id).update({
        'userId': user?.uid,
        'email': user?.email,
        'currentGroupId': "",
        'currentSubgroupId': [],
        'location': null,
        'name': "user",
      });
    } else {
      // ドキュメントがない場合は新規作成
      await FirebaseFirestore.instance.collection('USERS').doc(user?.uid).set({
        'userId': user?.uid,
        'email': user?.email,
        'currentGroupId': "",
        'currentSubgroupId': [],
        'location': null,
        'name': "user",
      });
    }
    _id = user?.uid ?? "";
  }

  // サインイン処理
  _signup() async {
    // サインイン中であることを示す
    setState(() {
      _isLoading = true;
    });
    try {
      if (_password != _checkpassword) {
        throw Exception("パスワードが一致しません");
      }
      final user = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email,
        password: _password,
      );
      _save(user.user);
      setState(() {
        _isLoading = false;
      });
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (context) => HomePage(user: user.user)));
    } catch (e) {
      // サインインに失敗したらエラーメッセージを表示
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // Googleアカウントでのサインイン処理
  _signUpWithGoogle() async {
    // ログイン中であることを示す
    setState(() {
      _isLoading = true;
    });
    try {
      if (kIsWeb) {
        // Webの場合
        // Googleアカウントでログインするためのダイアログを表示
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
        }
      } else {
        // Android、iOSの場合
        // Googleアカウントでログインするためのダイアログを表示
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
        }
      }
      _save(user);
      Navigator.pop(context, user);
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
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (context) => HomePage(user: user)));
    }
  }

  // サインインページの作成
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("登録"),
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
                    ),
                  ),
                  obscureText: _isHidepass,
                  onChanged: (value) {
                    setState(() {
                      _password = value;
                    });
                  },
                ),
              ),
            ]),
            // パスワードの確認
            Row(children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                      labelText: "パスワードを確認",
                      hintText: "パスワードを再度入力してください",
                      errorText: _hasError ? _errorMessage : null,
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _isHidecheckpass = !_isHidecheckpass;
                          });
                        },
                        icon: _isHidecheckpass
                            ? const Icon(Icons.visibility)
                            : const Icon(Icons.visibility_off),
                      )),
                  obscureText: _isHidecheckpass,
                  onChanged: (value) {
                    setState(() {
                      _checkpassword = value;
                    });
                  },
                ),
              ),
            ]),
            const SizedBox(height: 16),
            // サインインボタン
            SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _signup,
                  child: const Text("登録"),
                )),
            const SizedBox(height: 16),
            SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _signUpWithGoogle,
                  child: const Text("Googleでログイン"),
                )),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              const Text("すでにアカウントを持っていますか?"),
              const SizedBox(width: 8),
              TextButton(
                child: const Text(
                  "ログインする",
                  style: TextStyle(color: Colors.blue),
                ),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
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
