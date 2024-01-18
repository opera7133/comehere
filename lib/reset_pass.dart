import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ResetPassPage extends StatefulWidget {
  const ResetPassPage({super.key});

  @override
  _ResetPassPageState createState() => _ResetPassPageState();
}

// パスワードリセットページの作成
class _ResetPassPageState extends State<ResetPassPage> {
  // メールアドレスの入力値
  String _email = "";
  // パスワードリセットに関するエラーメッセージ
  String _errorMessage = "";
  // パスワードリセットに関するエラーが発生したかどうか
  bool _hasError = false;
  // パスワードリセット中かどうか
  bool _isLoading = false;

  // パスワードリセット処理
  _resetPass() async {
    // パスワードリセット中であることを示す
    setState(() {
      _isLoading = true;
    });
    try {
      // メールアドレスでパスワードリセット
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _email);
      // パスワードリセット中でないことを示す
      setState(() {
        _isLoading = false;
      });
      // パスワードリセット完了のダイアログを表示
      BuildContext innerContext;
      showDialog(
        context: context,
        builder: (BuildContext context) {
          innerContext = context;
          return AlertDialog(
            title: const Text("パスワードリセット完了"),
            content: const Text("パスワードリセットのメールを送信しました。"),
            actions: <Widget>[
              // ボタン領域
              TextButton(
                child: const Text("OK"),
                onPressed: () => Navigator.pop(innerContext),
              ),
            ],
          );
        },
      );
    } catch (e) {
      // パスワードリセット中でないことを示す
      setState(() {
        _isLoading = false;
      });
      // パスワードリセットに関するエラーメッセージを表示
      setState(() {
        _hasError = true;
        _errorMessage = "パスワードリセットに失敗しました。";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("パスワードリセット"),
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
            // パスワードリセットボタン
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                child: const Text("パスワードリセット"),
                onPressed: _isLoading ? null : _resetPass,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
