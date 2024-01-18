// プロフィール
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'setting_user.dart';
import 'setting_pass.dart';
import 'setting_view.dart';
import 'login.dart';

class ProfilePage extends StatefulWidget {
  final User? user;
  const ProfilePage({Key? key, required this.user}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

// プロフィールページの作成
class _ProfilePageState extends State<ProfilePage> {
  late Stream<DocumentSnapshot> userStream;
  Map? groupData;

  @override
  void initState() {
    super.initState();
    // FirestoreのコレクションパスとドキュメントIDを指定
    userStream = FirebaseFirestore.instance
        .collection('USERS')
        .doc(widget.user!.uid)
        .snapshots();
    getGroupData();
  }

  void getGroupData() async {
    // get USERS/uid/currentGroupId
    DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
        .collection('USERS')
        .doc(widget.user!.uid)
        .get();
    if (!(userSnapshot.data() as Map?)!.containsKey('currentGroupId')) {
      return;
    }
    DocumentSnapshot groupSnapshot = await FirebaseFirestore.instance
        .collection('GROUPS')
        .doc((userSnapshot.data() as Map?)!['currentGroupId'])
        .get();
    if (!groupSnapshot.exists) {
      return;
    }
    setState(() {
      groupData = groupSnapshot.data() as Map?;
    });
  }

  // ログアウト処理
  void logout() {
    FirebaseAuth.instance.signOut().then((value) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("プロフィール"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<DocumentSnapshot>(
          stream: userStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                  child: Text("Error: ${snapshot.error}",
                      style: const TextStyle(fontSize: 20, color: Colors.red)));
            }

            if (snapshot.hasData && snapshot.data!.exists) {
              Map<String, dynamic> userData =
                  snapshot.data!.data() as Map<String, dynamic>;
              String userName = widget.user?.displayName ?? '';
              String userIconUrl = userData['profilePicture'] ?? '';
              // 仮：'profilePicture'がプロフィール画像のURLを示すものとして

              return SingleChildScrollView(
                  child: Column(
                children: [
                  // ユーザーアイコン
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: NetworkImage(userIconUrl),
                  ),
                  const SizedBox(height: 8),
                  // ユーザー名
                  Text(userName, style: const TextStyle(fontSize: 20)),
                  // 参加グループ
                  const SizedBox(height: 16),
                  const Text("参加グループ", style: TextStyle(fontSize: 20)),
                  const SizedBox(height: 16),
                  if (groupData != null)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.group),
                      title: Text(groupData!['name']),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  if (groupData == null) const Text("参加グループはありません"),
                  const SizedBox(height: 16),
                  // 設定項目
                  const Text('設定', style: TextStyle(fontSize: 20)),
                  const SizedBox(height: 16),
                  _buildSettingButton(
                    icon: Icons.person,
                    label: 'ユーザー情報',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              UserinfoPage(user: widget.user!),
                        ),
                      );
                    },
                  ),
                  _buildSettingButton(
                    icon: Icons.lock,
                    label: 'パスワードの変更',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ChangePassPage(user: widget.user!),
                        ),
                      );
                    },
                  ),
                  _buildSettingButton(
                    icon: Icons.language,
                    label: '表示と言語',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ViewPage(user: widget.user!),
                        ),
                      );
                    },
                  ),
                  _buildSettingButton(
                      icon: Icons.account_balance,
                      label: "ライセンス",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LicensePage(
                              applicationName: "ComeHere",
                              applicationLegalese: "© 2024 Fighters",
                            ),
                          ),
                        );
                      }),
                  // ログアウト
                  _buildSettingButton(
                    icon: Icons.logout,
                    label: 'ログアウト',
                    onTap: () {
                      logout();
                    },
                    color: Colors.red,
                  ),
                ],
              ));
            }

            return const Text("User not found");
          },
        ),
      ),
    );
  }

  Widget _buildSettingButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.black,
  }) {
    return InkWell(
      onTap: onTap,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: color),
        title: Text(label, style: TextStyle(color: color)),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
