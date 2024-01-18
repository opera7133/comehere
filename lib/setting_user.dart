// 設定：ユーザー情報
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class UserinfoPage extends StatefulWidget {
  final User user;
  const UserinfoPage({Key? key, required this.user}) : super(key: key);

  @override
  _UserinfoPageState createState() => _UserinfoPageState();
}

// ユーザー情報ページの作成
class _UserinfoPageState extends State<UserinfoPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // ユーザー名とメールアドレスの入力値
  String _username = "";
  String _email = "";
  TextEditingController _usernameController = TextEditingController();
  TextEditingController _emailController = TextEditingController();
  // 変更に関するエラーメッセージ
  String _errorMessage = "";
  // 変更に関するエラーが発生したかどうか
  bool _hasError = false;
  // 変更中かどうか
  bool _isLoading = false;

  // アイコン変更処理
  _changeIcon() {
    setState(() {
      _isLoading = true;
    });
    try {} catch (e) {
      _hasError = true;
      _errorMessage = e.toString();
    } finally {
      // 変更が完了したらローディングを解除
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ユーザー名変更処理
  // コレクションとドキュメントID、更新するフィールドの値を指定して更新する
  Future<void> updateDocumentField(String collectionName, String documentId,
      String newName, String newMail) async {
    // 変更中であることを示す
    setState(() {
      _isLoading = true;
    });
    try {
      // Firestoreのコレクションとドキュメントのパスを指定
      CollectionReference collectionRef = _firestore.collection(collectionName);
      DocumentReference documentRef = collectionRef.doc(documentId);

      // 更新するフィールドと値を指定
      Map<String, dynamic> data = {
        'name': newName,
        'email': newMail,
      };

      // ドキュメントの更新
      await documentRef.update(data);
      if (widget.user.displayName != newName) {
        await widget.user.updateDisplayName(newName);
      }
      if (widget.user.email != newMail) {
        await widget.user.updateEmail(newMail);
      }
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

  // メール認証処理
  _authEmail() async {
    // 変更中であることを示す
    setState(() {
      _isLoading = true;
    });
    try {
      // メール認証
      widget.user.sendEmailVerification();
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

  @override
  void initState() {
    super.initState();
    _usernameController.text = widget.user.displayName ?? "";
    _username = widget.user.displayName ?? "";
    _emailController.text = widget.user.email ?? "";
    _email = widget.user.email ?? "";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("ユーザー情報"),
        ),
        body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(children: [
              // ユーザーアイコン編集
              // メールアドレス認証
              if (widget.user.emailVerified == true)
                const Text('メールアドレス認証済み',
                    style: TextStyle(color: Colors.green)),
              if (widget.user.emailVerified == false)
                const Text('メールアドレス未認証', style: TextStyle(color: Colors.red)),
              // ユーザー名の入力
              const SizedBox(
                height: 16,
              ),
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: "ユーザー名",
                  hintText: "ユーザー名を入力してください",
                  errorText: _hasError ? _errorMessage : null,
                ),
                onChanged: (value) {
                  setState(() {
                    _username = value;
                  });
                },
              ),
              // メールアドレスの入力
              TextField(
                controller: _emailController,
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
              // 認証メール送信ボタン
              widget.user.emailVerified
                  ? Container()
                  : ElevatedButton(
                      child: const Text("認証メールを送信"),
                      onPressed: () {
                        if (_isLoading) {
                          return;
                        }
                        _authEmail();
                      },
                    ),
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
                            updateDocumentField(
                                "USERS", widget.user.uid, _username, _email);
                          },
                        ),
                      ]))
            ])));
  }
}
