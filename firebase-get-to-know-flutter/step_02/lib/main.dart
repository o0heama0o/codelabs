import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'src/authentication.dart';
import 'src/widgets.dart';


void main() async{
  //WidgetsFlutterBinding.ensureInitialized();
  //await Firebase.initializeApp();
  runApp(
    //changeNotifierProvider 하위에 있는건 다 listener가 된다.
    ChangeNotifierProvider(
      create: (context) => ApplicationState(), //changeNotifier를 상속받은 class
      builder: (context, _) => App(), //App class 하위는 다 Listener
    ),
  );
}

//main()에서 호출
class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firebase Meetup',
      theme: ThemeData(
        buttonTheme: Theme.of(context).buttonTheme.copyWith(
              highlightColor: Colors.deepPurple,
            ),
        primarySwatch: Colors.deepPurple,
        textTheme: GoogleFonts.robotoTextTheme(
          Theme.of(context).textTheme,
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity, //이게뭐야
      ),
      home: HomePage(),
    );
  }
}

//App에서 호출
class HomePage extends StatelessWidget {
  HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Firebase Meetup'),
      ),
      body: ListView(
        children: <Widget>[
          Image.asset('assets/codelab.png'),
          SizedBox(height: 8),
          IconAndDetail(Icons.calendar_today, 'October 30'),
          IconAndDetail(Icons.location_city, 'San Francisco'),
          //consumer widget (현 application state에 대한 각종 정보 가져오기
          Consumer<ApplicationState>( // provider ApplicationState class 사용(밑에 있음)
            builder: (context, appState, _) => Authentication( //provider에서 제공받은 정보는 Authentication class로. (RSVP버튼이 거기있어)
              email: appState.email,
              loginState: appState.loginState,
              startLoginFlow: appState.startLoginFlow,
              verifyEmail: appState.verifyEmail,
              signInWithEmailAndPassword: appState.signInWithEmailAndPassword,
              cancelRegistration: appState.cancelRegistration,
              registerAccount: appState.registerAccount,
              signOut: appState.signOut,
            ),
          ),
          //to here
          Divider(
            height: 8,
            thickness: 1,
            indent: 8,
            endIndent: 8,
            color: Colors.grey,
          ),
          Header("What we'll be doing"),
          Paragraph(
            'Join us for a day full of Firebase Workshops and Pizza!',
          ),

          //chating 부분
          Consumer<ApplicationState>(
            builder: (context, appState, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Add from here
                if (appState.attendees >= 2)
                  Paragraph('${appState.attendees} people going')
                else if (appState.attendees == 1)
                  Paragraph('1 person going')
                else
                  Paragraph('No one going'),
                // To here.
                if (appState.loginState == ApplicationLoginState.loggedIn) ...[
                  // Add from here
                  YesNoSelection(
                    state: appState.attending,
                    onSelection: (attending) => appState.attending = attending,
                  ),
                  // To here.
                  Header('Discussion'),
                  GuestBook(
                    addMessage: (String message) =>
                        appState.addMessageToGuestBook(message),
                    messages: appState.guestBookMessages,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

//----------------for login(Firebase Athentication)----------------
class ApplicationState extends ChangeNotifier {
  ApplicationState() {
    init();
  }
  //쉽게 말해서 async 함수는 await가 붙은 함수가 다 끝날때까지 다음 동작을 실행하지 않고 기다림
  // Future : 지금은 없지만 미래에 요청한 데이터 혹은 에러가 담길 그릇
  //login과 logout 상태만 계속 체크하는 듯
  Future<void> init() async {
    await Firebase.initializeApp(); //이게 끝날 때 까지 뒤에는 실행 안됨.

    FirebaseFirestore.instance
        .collection('attendees')
        .where('attending', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      _attendees = snapshot.docs.length;
      notifyListeners();
    });

    //로그인하기 (firebase로 부터 로그인 여부가 들어오는지 계속 listen하고있음)
    FirebaseAuth.instance.userChanges().listen((user) {
      if (user != null) {
        //login이 되어있는 거니까 state를 login으로 바꿈
        _loginState = ApplicationLoginState.loggedIn;
        //login이 되어있는 거니까 cloud firestore 사용 준비
        _guestBookSubscription = FirebaseFirestore.instance
            .collection('guestbook')
            .orderBy('timestamp', descending: true)
            .snapshots()
            .listen((snapshot) {
          _guestBookMessages = [];
          snapshot.docs.forEach((document) {
            _guestBookMessages.add(
              GuestBookMessage(
                //name: document.data()['name'],
                name : 'name',
                message: document.data()['text'],
              ),
            );
          });
          notifyListeners();
        });
        _attendingSubscription = FirebaseFirestore.instance
            .collection('attendees')
            .doc(user.uid)
            .snapshots()
            .listen((snapshot) {
          if (snapshot.data() != null) {
            if (snapshot.data()!['attending']) {
              _attending = Attending.yes;
            } else {
              _attending = Attending.no;
            }
          } else {
            _attending = Attending.unknown;
          }
          notifyListeners();
        });
      } else {
        _loginState = ApplicationLoginState.loggedOut;
        _guestBookMessages = [];
        _guestBookSubscription?.cancel();
        _attendingSubscription?.cancel();
      }
      notifyListeners(); // 리스너한테 알리기
    });
  }

  ApplicationLoginState _loginState = ApplicationLoginState.loggedOut; //기본적으로는 로그아웃 상태
  ApplicationLoginState get loginState => _loginState; //외부호출용

  String? _email; //이메일 저장
  String? get email => _email; //외부호출용

  StreamSubscription<QuerySnapshot>? _guestBookSubscription;
  List<GuestBookMessage> _guestBookMessages = [];
  List<GuestBookMessage> get guestBookMessages => _guestBookMessages;

  int _attendees = 0;
  int get attendees => _attendees;

  Attending _attending = Attending.unknown;
  StreamSubscription<DocumentSnapshot>? _attendingSubscription;
  Attending get attending => _attending;
  set attending(Attending attending) {
    final userDoc = FirebaseFirestore.instance
        .collection('attendees')
        .doc(FirebaseAuth.instance.currentUser!.uid);
    if (attending == Attending.yes) {
      userDoc.set({'attending': true});
    } else {
      userDoc.set({'attending': false});
    }
  }

  //login flow 호출
  void startLoginFlow() {
    _loginState = ApplicationLoginState.emailAddress; // loginstate 업데이트  ( applicationLoginState는 authentication.dart에)
    notifyListeners(); //listener한테 알림
  }

  //이메일
  void verifyEmail(
      String email,
      void Function(FirebaseAuthException e) errorCallback,
      ) async {
    try {
      var methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);

      //가입이 되어있는 경우
      if (methods.contains('password')) {//(fb의'password'에 유저가 입력한 정보가 있으면 이제 로그인하면되는)
        _loginState = ApplicationLoginState.password; //로그인하라고
      }
      //가입을 아직 안한경우
      else {
        _loginState = ApplicationLoginState.register; //loginstate를 resgister(회원가입)으로 변경
      }
      _email = email;
      notifyListeners(); //리스너한테 전달
    } on FirebaseAuthException catch (e) {
      errorCallback(e);
    }
  }

  //가입이되어있는 계정에 한에서 로그인
  void signInWithEmailAndPassword(
      String email,
      String password,
      void Function(FirebaseAuthException e) errorCallback,
      ) async {
    try { //여기서 로그인이 되면 ApplicationLoginState가 login이 되면서 위에있는 future init이 로그인감지하고 notifylisetener() 실행함.
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      errorCallback(e);
    }
  }

  //회원가입 취소
  void cancelRegistration() {
    _loginState = ApplicationLoginState.emailAddress; // 이메일 입력하는 단계로 돌아가야함.
    notifyListeners();
  }

  // 회원가입
  void registerAccount(String email, String displayName, String password,
      void Function(FirebaseAuthException e) errorCallback) async {
    try {
      //새로운 어카운트 객체만
      var credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
      await credential.user!.updateProfile(displayName: displayName); //update
    } on FirebaseAuthException catch (e) {
      errorCallback(e);
    }
  }

  //로그아웃
  void signOut() {
    FirebaseAuth.instance.signOut();
  }

  Future<DocumentReference> addMessageToGuestBook(String message) {
    if (_loginState != ApplicationLoginState.loggedIn) {
      throw Exception('Must be logged in');
    }

    return FirebaseFirestore.instance.collection('guestbook').add({
      'text': message,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'name': FirebaseAuth.instance.currentUser!.displayName,
      'userId': FirebaseAuth.instance.currentUser!.uid,
    });
  }
}


//----------------for messaging(Cloud Firestore)----------------

class GuestBookMessage {
  GuestBookMessage({required this.name, required this.message});
  final String name;
  final String message;
}

enum Attending { yes, no, unknown }

//새 상태 저장을 위한 위젯
class GuestBook extends StatefulWidget {
  GuestBook({required this.addMessage, required this.messages});
  final FutureOr<void> Function(String message) addMessage;
  final List<GuestBookMessage> messages;

  @override
  _GuestBookState createState() => _GuestBookState();
}

class _GuestBookState extends State<GuestBook> {
  final _formKey = GlobalKey<FormState>(debugLabel: '_GuestBookState');
  final _controller = TextEditingController();

  @override
  // Modify from here
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // to here.
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Form(
            key: _formKey,
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Leave a message',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Enter your message to continue';
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(width: 8),
                StyledButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      await widget.addMessage(_controller.text);
                      _controller.clear();
                    }
                  },
                  child: Row(
                    children: [
                      Icon(Icons.send),
                      SizedBox(width: 4),
                      Text('SEND'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Modify from here
        SizedBox(height: 8),
        for (var message in widget.messages)
          //Paragraph('${message.name}: ${message.message}'),
          Paragraph('name: ${message.message}'),
        SizedBox(height: 8),
        SizedBox(
          height: 8,
          child: const DecoratedBox(
            decoration: const BoxDecoration(
                color: Colors.red
            ),
          ),
        ),
      ],
      // to here.
    );
  }
}

class YesNoSelection extends StatelessWidget {
  const YesNoSelection({required this.state, required this.onSelection});
  final Attending state;
  final void Function(Attending selection) onSelection;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case Attending.yes:
        return Padding(
          padding: EdgeInsets.all(8.0),
          child: Row(
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(elevation: 0),
                onPressed: () => onSelection(Attending.yes),
                child: Text('YES'),
              ),
              SizedBox(width: 8),
              TextButton(
                onPressed: () => onSelection(Attending.no),
                child: Text('NO'),
              ),
            ],
          ),
        );
      case Attending.no:
        return Padding(
          padding: EdgeInsets.all(8.0),
          child: Row(
            children: [
              TextButton(
                onPressed: () => onSelection(Attending.yes),
                child: Text('YES'),
              ),
              SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(elevation: 0),
                onPressed: () => onSelection(Attending.no),
                child: Text('NO'),
              ),
            ],
          ),
        );
      default:
        return Padding(
          padding: EdgeInsets.all(8.0),
          child: Row(
            children: [
              StyledButton(
                onPressed: () => onSelection(Attending.yes),
                child: Text('YES'),
              ),
              SizedBox(width: 8),
              StyledButton(
                onPressed: () => onSelection(Attending.no),
                child: Text('NO'),
              ),
            ],
          ),
        );
    }
  }
}
