import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:jashan/pages/front/front_page.dart';

class RegisterPage extends FrontPage {
  @override
  State<StatefulWidget> createState() {
    return _RegisterPageState();
  }

  static void signUp(String username, String email, String password) async {
    await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email, password: password);
    await Firestore.instance.collection('users').add(
      {
        'username': username,
        'email': email,
      },
    );
  }
}

class _RegisterPageState extends State<RegisterPage> {
  String _username;
  String _password;
  String _email;
  String _usernameValidation;
  String _emailValidation;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = new TextEditingController();
  final TextEditingController _emailController = new TextEditingController();
  final TextEditingController _passwordController = new TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Image.asset("assets/images/jashan_white.png"),
            SizedBox(
              height: 50,
            ),
            Form(
              key: _formKey,
              child: Column(
                children: <Widget>[
                  Container(
                    width: MediaQuery.of(context).size.width * 0.7,
                    child: TextFormField(
                      validator: (username) {
                        return _usernameValidation;
                      },
                      controller: _usernameController,
                      onSaved: (username) => _username = username,
                      decoration: InputDecoration(
                        suffixIcon: Icon(
                          Icons.person_outline,
                          color: Theme.of(context).accentColor,
                        ),
                        hintStyle: TextStyle(color: Theme.of(context).accentColor),
                        border: UnderlineInputBorder(),
                        hintText: 'Username',
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Container(
                    width: MediaQuery.of(context).size.width * 0.7,
                    child: TextFormField(
                      validator: (email) {
                        return _emailValidation;
                      },
                      controller: _emailController,
                      onSaved: (email) => _email = email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        suffixIcon: Icon(
                          Icons.alternate_email,
                          color: Theme.of(context).accentColor,
                        ),
                        hintStyle: TextStyle(color: Theme.of(context).accentColor),
                        border: UnderlineInputBorder(),
                        hintText: 'Email',
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Container(
                    width: MediaQuery.of(context).size.width * 0.7,
                    child: TextFormField(
                      validator: (password) {
                        if (password.isEmpty) {
                          return 'Your password can\'t be blank.';
                        }
                        return null;
                      },
                      onSaved: (password) => _password = password,
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        suffixIcon: Icon(
                          Icons.lock_outline,
                          color: Theme.of(context).accentColor,
                        ),
                        hintStyle: TextStyle(color: Theme.of(context).accentColor),
                        border: UnderlineInputBorder(),
                        hintText: 'Password',
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Container(
                    width: MediaQuery.of(context).size.width * 0.7,
                    child: TextFormField(
                      validator: (passwordConfirmed) {
                        if (passwordConfirmed.isEmpty) {
                          return 'Your password can\'t be blank.';
                        } else if (_passwordController.text !=
                            passwordConfirmed) {
                          return 'Your passwords do not match each other.';
                        }
                        return null;
                      },
                      obscureText: true,
                      decoration: InputDecoration(
                        suffixIcon: Icon(
                          Icons.lock_outline,
                          color: Theme.of(context).accentColor,
                        ),
                        hintStyle: TextStyle(color: Theme.of(context).accentColor),
                        border: UnderlineInputBorder(),
                        hintText: 'Confirm password',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 30,
            ),
            SizedBox(
              width: MediaQuery.of(context).size.width / 2,
              child: RaisedButton(
                child: Text(
                  "SIGN UP",
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                color: Theme.of(context).accentColor,
                onPressed: () {
                  _signUp(context);
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(75),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future _signUp(BuildContext context) async {
    await _validateUsername();
    await _validateEmail();
    if (_formKey.currentState.validate()) {
      _formKey.currentState.save();
      try {
        RegisterPage.signUp(_username, _email, _password);
        Navigator.pushReplacementNamed(context, '/');
      } catch (e) {
        print(e.message);
      }
    }
  }

  Future _validateUsername() async {
    if (_usernameController.text.isEmpty) {
      _usernameValidation = 'Your username can\'t be blank.';
    } else {
      bool usernameUsed = await _isUsed('username', _usernameController.text);
      if (usernameUsed) {
        _usernameValidation = 'That username is already in use.';
      } else {
        _usernameValidation = null;
      }
    }
  }

  Future _validateEmail() async {
    if (_emailController.text.isEmpty) {
      _emailValidation = 'Your email can\'t be blank.';
    } else {
      bool emailUsed = await _isUsed('email', _emailController.text);
      if (emailUsed) {
        _emailValidation = 'That email is already in use.';
      } else {
        _emailValidation = null;
      }
    }
  }

  Future<bool> _isUsed(String field, String value) async {
    QuerySnapshot snapshot = await Firestore.instance
        .collection('users')
        .where(field, isEqualTo: value)
        .getDocuments();
    if (snapshot.documents.isNotEmpty) {
      return true;
    } else {
      return false;
    }
  }
}
