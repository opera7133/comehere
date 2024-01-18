// 設定：パスワードの変更
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChangePassPage extends StatefulWidget {
  final User user;
  const ChangePassPage({Key? key, required this.user}) : super(key: key);

  @override
  _ChangePassPageState createState() => _ChangePassPageState();
}

// パスワード変更ページの作成
class _ChangePassPageState extends State<ChangePassPage> {
  // メールアドレスとパスワードの入力値
  String _lastpassword = "";
  String _newpassword = "";
  String _checkpassword = "";
  // パスワード変更に関するエラーメッセージ
  String _errorMessage = "";
  // パスワード変更に関するエラーが発生したかどうか
  bool _hasError = false;
  // 変更中かどうか
  bool _isLoading = false;

  // パスワード変更処理
  Future<void> _changepass() async {
    // 変更中であることを示す
    setState(() {
      _isLoading = true;
    });
    try {
      // 現在のパスワードを確認
      final _ = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: widget.user.email!,
        password: _lastpassword,
      );
      // パスワードの変更
      if (_newpassword != _checkpassword) {
        throw Exception("新しいパスワードが一致しません");
      }
      widget.user.updatePassword(_newpassword);
      Navigator.pop(context);
    } catch (e) {
      // 変更中に失敗したらエラーメッセージを表示
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
    } finally {
      // 変更が完了したらローディングを解除
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ハスワードの変更ページの作成
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("パスワードの変更"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 現在のパスワードの入力
            TextField(
              decoration: InputDecoration(
                labelText: "現在のパスワード",
                hintText: "現在のパスワードを入力してください",
                errorText: _hasError ? _errorMessage : null,
              ),
              obscureText: true,
              onChanged: (value) {
                setState(() {
                  _lastpassword = value;
                });
              },
            ),
            // 新しいパスワードの入力
            TextField(
              decoration: InputDecoration(
                labelText: "新しいパスワード",
                hintText: "新しいパスワードを入力してください",
                errorText: _hasError ? _errorMessage : null,
              ),
              onChanged: (value) {
                setState(() {
                  _newpassword = value;
                });
              },
            ),
            // パスワードの入力
            TextField(
              decoration: InputDecoration(
                labelText: "新しいパスワードの確認",
                hintText: "新しいパスワードを入力してください",
                errorText: _hasError ? _errorMessage : null,
              ),
              obscureText: true,
              onChanged: (value) {
                setState(() {
                  _checkpassword = value;
                });
              },
            ),
            const SizedBox(height: 16),
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 戻るボタン
                      ElevatedButton(
                        child: const Text("戻る"),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                      // 変更ボタン
                      ElevatedButton(
                        child: const Text("変更"),
                        onPressed: () {
                          if (_isLoading) {
                            return;
                          }
                          _changepass();
                        },
                      ),
                    ]))
          ],
        ),
      ),
    );
  }
}
