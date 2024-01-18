// 設定：表示と言語
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ViewPage extends StatefulWidget {
  final User user;
  const ViewPage({Key? key, required this.user}) : super(key: key);

  @override
  _ViewPageState createState() => _ViewPageState();
}

// プロフィールページの作成
class _ViewPageState extends State<ViewPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // テーマカラー、言語の入力値
  String _color = "";
  String _language = "日本語";
  // 変更に関するエラーメッセージ
  String _errorMessage = "";
  // 変更に関するエラーが発生したかどうか
  bool _hasError = false;
  // 変更中かどうか
  bool _isLoading = false;
  // 変更可能なカラーのリスト
  List<Color> fixedColors = [
    Colors.blue,
    Colors.red,
    Colors.cyan,
    Colors.pink,
    Colors.black,
    Colors.purple,
    Colors.lime,
    Colors.yellow,
    Colors.deepPurple,
    Colors.orange,
  ];

  // 表示変更処理
  _changeview() async {
    // 変更中であることを示す
    setState(() {
      _isLoading = true;
    });
    try {
      // テーマカラー変更
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString("color", _color);
      // 言語変更
      await prefs.setString("lang", _language);
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

  @override
  void initState() {
    super.initState();
    _getPreferences();
  }

  _getPreferences() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _color = prefs.getString("color") ?? "";
      _language = prefs.getString("lang") ?? "日本語";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("表示と言語"),
        ),
        body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(children: [
              const Text("テーマ", style: TextStyle(fontSize: 16)),
              const SizedBox(
                height: 16,
              ),
              // テーマ選択
              GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 8.0,
                  crossAxisSpacing: 8.0,
                ),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: fixedColors.length,
                itemBuilder: (BuildContext context, int index) {
                  Color buttonColor = fixedColors[index];
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _color = buttonColor.toString(); // カラーを文字列として保持
                      });
                    },
                    child: Container(
                      width: 10.0,
                      height: 10.0,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: buttonColor,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(
                height: 16,
              ),
              const Text("言語", style: TextStyle(fontSize: 16)),
              const SizedBox(
                height: 16,
              ),
              // 言語選択
              DropdownMenu<String>(
                initialSelection: _language,
                onSelected: (String? newValue) {
                  setState(() {
                    _language = newValue!;
                  });
                },
                dropdownMenuEntries: <String>['日本語', 'English']
                    .map<DropdownMenuEntry<String>>((String value) {
                  return DropdownMenuEntry<String>(
                    value: value,
                    label: value, // 言語を文字列として保持
                  );
                }).toList(),
              ),
              const SizedBox(
                height: 16,
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
                          onPressed: _isLoading
                              ? null
                              : () async {
                                  await _changeview();
                                },
                          child: const Text("変更"),
                        ),
                      ])),
            ])));
  }
}
