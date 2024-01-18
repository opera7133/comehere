import 'package:flutter/material.dart';
import 'package:textfield_tags/textfield_tags.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddUserPage extends StatefulWidget {
  final Map? group;
  final Map? user;
  const AddUserPage({Key? key, this.user, this.group}) : super(key: key);

  @override
  State<AddUserPage> createState() => _AddUserPageState();
}

class _AddUserPageState extends State<AddUserPage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  Map? group;
  Map? user;
  String error = "";
  String success = "";
  final _userIdController = TextfieldTagsController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    group = widget.group;
    user = widget.user;
  }

  // ユーザーを招待する
  Future<void> addUser() async {
    setState(() {
      error = "";
      success = "";
    });
    if (_formKey.currentState!.validate()) {
      List<String>? uids = _userIdController.getTags!;
      for (String uid in uids) {
        QuerySnapshot users = await firestore
            .collection("USERS")
            .where("email", isEqualTo: uid)
            .get();
        if (users.docs.isNotEmpty) {
          Map<String, dynamic> userData =
              users.docs[0].data() as Map<String, dynamic>;
          if (userData["currentGroupId"] == group!["groupId"]) {
            setState(() {
              error += "$uid : 既にグループに所属しています\n";
            });
            continue;
          }
          await firestore
              .collection("INVITES")
              .where("toId", isEqualTo: userData["userId"])
              .where("groupId", isEqualTo: group!["groupId"])
              .get()
              .then((value) async {
            if (value.docs.isNotEmpty) {
              setState(() {
                error += "$uid : 既に招待通知が送信されています\n";
              });
              return;
            } else {
              String newDoc = firestore.collection("INVITES").doc().id;
              await firestore.collection("INVITES").doc(newDoc).set({
                "createdAt": FieldValue.serverTimestamp(),
                "groupType": group!["type"],
                "fromId": user!["userId"],
                "toId": userData["userId"],
                "groupId": group!["groupId"],
                "message": "${user!["name"]}さんから「${group!["name"]}」への招待が届いています",
                "inviteId": newDoc,
                "type": "Invite",
              });
              setState(() {
                success += "$uid : 招待通知を送信しました\n";
              });
            }
          });
        } else {
          setState(() {
            error += "$uid : ユーザーが見つかりませんでした\n";
          });
        }
      }
      _userIdController.clearTags();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(28, 36, 28, 36),
        child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.arrow_back, size: 32)),
                const Text("ユーザーを招待", style: TextStyle(fontSize: 32)),
                const Text("登録されているユーザーに招待通知を送ります。"),
                Text(success, style: const TextStyle(color: Colors.green)),
                Text(error, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 10),
                TextFieldTags(
                    validator: (tag) {
                      if (tag.isNotEmpty) {
                        return null;
                      }
                      return "メールアドレスを入力してください";
                    },
                    initialTags: const [],
                    textfieldTagsController: _userIdController,
                    textSeparators: const [" ", ","],
                    inputfieldBuilder:
                        (context, tec, fn, error, onChanged, onSubmitted) {
                      return (((context, sc, tags, onDeleteTag) {
                        return TextField(
                          controller: tec,
                          focusNode: fn,
                          onChanged: onChanged,
                          onSubmitted: onSubmitted,
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            hintText: "メールアドレス",
                            prefixIcon: tags.isNotEmpty
                                ? SingleChildScrollView(
                                    controller: sc,
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                        children: tags.map((String tag) {
                                      return Container(
                                        decoration: const BoxDecoration(
                                          borderRadius: BorderRadius.all(
                                            Radius.circular(20.0),
                                          ),
                                          color:
                                              Color.fromARGB(255, 61, 61, 61),
                                        ),
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 5.0),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10.0, vertical: 5.0),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            InkWell(
                                              child: Text(
                                                tag,
                                                style: const TextStyle(
                                                    color: Colors.white),
                                              ),
                                            ),
                                            const SizedBox(width: 4.0),
                                            InkWell(
                                              child: const Icon(
                                                Icons.cancel,
                                                size: 14.0,
                                                color: Color.fromARGB(
                                                    255, 233, 233, 233),
                                              ),
                                              onTap: () {
                                                onDeleteTag(tag);
                                              },
                                            )
                                          ],
                                        ),
                                      );
                                    }).toList()),
                                  )
                                : null,
                          ),
                        );
                      }));
                    }),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      addUser();
                    },
                    child: const Text("招待する"),
                  ),
                ),
              ],
            )),
      ),
    );
  }
}
