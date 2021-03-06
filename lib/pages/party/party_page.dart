import 'dart:collection';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart';
import 'package:jashan/data/party_info.dart';
import 'package:jashan/data/track.dart';
import 'package:jashan/data/track_queue_item.dart';
import 'package:jashan/data/user.dart';
import 'package:jashan/pages/party/end_party_page.dart';
import 'package:jashan/pages/party/party_page_searching.dart';
import 'package:jashan/util/jashan_queue_list.dart';
import 'package:jashan/util/sorted_queue_list.dart';
import 'package:jashan/util/spotify_player.dart';
import 'package:jashan/util/spotify_utilities.dart';
import 'package:jashan/util/text_utilities.dart';
import 'package:jashan/widgets/track_info_view.dart';
import 'package:jashan/widgets/track_queue_item_card.dart';

class PartyPage extends StatefulWidget {
  final PartyInfo partyInfo;
  final List<Track> initialTracks;
  final JashanUser user;

  PartyPage(
      {@required this.partyInfo,
      @required this.user,
      this.initialTracks});

  @override
  State<StatefulWidget> createState() {
    return PartyPageState();
  }
}

class PartyPageState extends State<PartyPage> {
  static const String START_PARTY_COMMAND = "start party";
  final QueueList<TrackQueueItem> _queue = new SortedQueueList();
  final Map<String, TrackQueueItem> _songs = new HashMap();
  final Map<String, JashanQueueList<String>> _votes = new Map();
  final Map<String, JashanQueueList<String>> _downvotes = new Map();
  TrackQueueItem _currentlyPlayingSong;
  SpotifyPlayer _spotifyPlayer;
  bool _partyStarted = false;
  bool _partyPaused = false;
  final GlobalKey scaffoldKey = new GlobalKey();

  @override
  void initState() {
    super.initState();
    _spotifyPlayer = new SpotifyPlayer(
      user: widget.partyInfo.owner,
      onSongEnd: () {
        if (!_partyStarted || _currentlyPlayingSong == null) {
          return;
        }
        setState(() {
          widget.partyInfo.firebaseDocument.collection('tracks').document(_currentlyPlayingSong.uri).delete();
          if (_queue.length >= 1) {
            _currentlyPlayingSong = _queue.removeFirst();
            widget.partyInfo.songs.add(_currentlyPlayingSong);
            if (widget.user == widget.partyInfo.owner) {
              _spotifyPlayer.playSong(_currentlyPlayingSong);
            }
          } else if (_queue.length == 0) {
            _currentlyPlayingSong = null;
            _partyStarted = false;
            _partyPaused = false;
          }
        });
      },
      onSongStart: () async {
        Track currentSong = await _spotifyPlayer.getCurrentSongPlaying();
        if (currentSong.uri == _currentlyPlayingSong.uri) {
          setState(() {
            _partyPaused = false;
          });
        }
      },
      onSongPause: () {
        setState(() {
          _partyPaused = true;
        });
      },
      onSongChange: () async {
        Track currentSong = await _spotifyPlayer.getCurrentSongPlaying();
        if (currentSong == null || _currentlyPlayingSong.uri == null) {
          return;
        }
        if (currentSong.uri != _currentlyPlayingSong.uri) {
          setState(() {
            _partyPaused = true;
          });
        }
      },
    );
    widget.partyInfo.firebaseDocument.collection('tracks').snapshots().listen((data) {
      data.documentChanges.forEach((change) {
        var document = change.document;
        if (change.type == DocumentChangeType.added) {
          _addSongToQueue(document);
        }
      });
    });
    if (widget.initialTracks != null) {
      widget.initialTracks.forEach((item) {
        var trackQueueItem =
            new TrackQueueItem.fromTrack(item, addedBy: widget.partyInfo.owner.username, addedTimeStamp: new DateTime.now().millisecondsSinceEpoch);
        _addSongToDatabase(trackQueueItem);
      });
    }
    var usersCollection = widget.partyInfo.firebaseDocument.collection('users');
    usersCollection.snapshots().listen((data) {
      data.documentChanges.forEach((change) {
        var username = change.document.documentID;
        if (change.type == DocumentChangeType.added) {
          _votes['"$username"'] = new JashanQueueList<String>(cap: 5);
          _downvotes['"!$username"'] = new JashanQueueList<String>(cap: 5);
          usersCollection
              .document(username)
              .collection('upvotes')
              .snapshots()
              .listen((data) {
            data.documentChanges.forEach((change) {
              if (change.type == DocumentChangeType.added) {
                _votes['"$username"'].add(change.document.documentID);
              } else if (change.type == DocumentChangeType.removed) {
                _votes['"$username"'].remove(change.document.documentID);
              }
            });
          });
          usersCollection
              .document(username)
              .collection('downvotes')
              .snapshots()
              .listen((data) {
            data.documentChanges.forEach((change) {
              if (change.type == DocumentChangeType.added) {
                _downvotes['"!$username"'].add(change.document.documentID);
              } else if (change.type == DocumentChangeType.removed) {
                _downvotes['"!$username"'].remove(change.document.documentID);
              }
            });
          });
        } else if (change.type == DocumentChangeType.removed) {
          _votes.remove('"$username"');
        }
      });
    });
    var commandsCollection = widget.partyInfo.firebaseDocument.collection('commands');
    commandsCollection.snapshots().listen((data) {
      data.documentChanges.forEach((change) {
        var command = change.document.documentID;
        if (change.type == DocumentChangeType.added) {
          if (command == START_PARTY_COMMAND) {
            _startParty();
            change.document.reference.delete();
          }
        }
      });
    });
  }

  void _addSongToQueue(DocumentSnapshot snapshot) {
    TrackQueueItem trackQueueItem =
        TrackQueueItem.fromDocumentReference(snapshot);
    _songs[snapshot.data['uri']] = trackQueueItem;
    _addVoteListeners(trackQueueItem.uri);
    setState(() => _queue.add(trackQueueItem));
    // todo if weird order, enforce async
  }

  void _addVoteListeners(String uri) {
    var songDocument = widget.partyInfo.firebaseDocument.collection('tracks').document(uri);
    songDocument.collection('upvotes').snapshots().listen((data) {
      data.documentChanges.forEach((change) {
        String username = change.document.documentID;
        var userVotesDocument =
            widget.partyInfo.firebaseDocument.collection('users').document(username);
        userVotesDocument.setData({});
        if (change.type == DocumentChangeType.added) {
          _songs[uri].upvotes.add(username);
          userVotesDocument.collection('upvotes').document(uri).setData({});
        } else if (change.type == DocumentChangeType.removed) {
          _songs[uri].upvotes.remove(username);
          userVotesDocument.collection('upvotes').document(uri).delete();
        }
        setState(() => _queue.sort());
      });
    });
    songDocument.collection('downvotes').snapshots().listen((data) {
      data.documentChanges.forEach((change) {
        String username = change.document.documentID;
        var userDownvotesDocument =
            widget.partyInfo.firebaseDocument.collection('users').document(username);
        userDownvotesDocument.setData({});
        if (change.type == DocumentChangeType.added) {
          _songs[uri].downvotes.add(username);
          userDownvotesDocument.collection('downvotes').document(uri).setData({});
        } else if (change.type == DocumentChangeType.removed) {
          _songs[uri].downvotes.remove(username);
          userDownvotesDocument.collection('downvotes').document(uri).delete();
        }
        setState(() => _queue.sort());
      });
    });
  }

  void _addSongToDatabase(TrackQueueItem trackQueueItem) {
    var songDocument =
        widget.partyInfo.firebaseDocument.collection('tracks').document(trackQueueItem.uri);
    songDocument.setData({
      'thumbnail_url': trackQueueItem.thumbnailUrl,
      'title': trackQueueItem.title,
      'artist': trackQueueItem.artist,
      'uri': trackQueueItem.uri,
      'duration_ms': trackQueueItem.durationMs,
      'added_by': trackQueueItem.addedBy,
      'added_time_stamp': trackQueueItem.addedTimeStamp,
    });
  }

  @override
  Widget build(BuildContext context) {
    AppBar appBar = AppBar(
      iconTheme: Theme.of(context).iconTheme,
      actions: <Widget>[
        SizedBox(
          width: 20,
        ),
        InkWell(
          child: Icon(Icons.add),
          onTap: () => _openSearch(),
        ),
        SizedBox(
          width: 20,
        ),
      ],
    );
    return Scaffold(
      appBar: appBar,
      key: scaffoldKey,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              flex: 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  Text(
                    getTextWithCap(widget.partyInfo.title, 16),
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 30,
                    ),
                  ),
                  Divider(color: Colors.black),
                ],
              ),
            ),
            Expanded(
              flex: 8,
              child: _queue.isEmpty && _currentlyPlayingSong == null
                  ? Center(
                      child: Text(
                        'No songs!',
                        style: TextStyle(color: Colors.black),
                      ),
                    )
                  : ListView.builder(
                      itemBuilder: (BuildContext context, int index) {
                        TrackQueueItem data;
                        if (_currentlyPlayingSong == null) {
                          data = _queue[index];
                        } else if (index == 0 &&
                            _currentlyPlayingSong != null) {
                          data = _currentlyPlayingSong;
                        } else if (index != 0 &&
                            _currentlyPlayingSong != null) {
                          data = _queue[index - 1];
                        }
                        return TrackQueueItemCard(
                          data: data,
                          onLongPress: () => _showTrackInfo(appBar, data),
                          onUpvoteChange: (increase) =>
                              _onSongVote(index, data, increase),
                          isCurrentPlaying:
                              !_partyPaused && data == _currentlyPlayingSong,
                          user: widget.user,
                          titleChars: 18,
                          artistChars: 22,
                        );
                      },
                      itemCount: _queue.length +
                          (_currentlyPlayingSong == null ? 0 : 1),
                    ),
            ),
            Expanded(
              flex: 1,
              child: widget.user == widget.partyInfo.owner
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        SizedBox(
                          width: MediaQuery.of(context).size.width / 2 - 30,
                          height: 50,
                          child: RaisedButton(
                            child: Text(
                              _partyStarted
                                  ? _partyPaused
                                      ? "Continue Party"
                                      : "End Party"
                                  : "Start Party",
                              style: TextStyle(
                                color: Theme.of(context).accentColor,
                                fontSize: 20,
                              ),
                            ),
                            color: Theme.of(context).primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(75),
                            ),
                            onPressed: !_partyStarted
                                ? _issueStartPartyCommand
                                : _partyPaused ? _continueParty : _endParty,
                          ),
                        ),
                        _moreInfoButton(
                            MediaQuery.of(context).size.width / 2 - 30, true),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        _moreInfoButton(
                            MediaQuery.of(context).size.width / 2, false)
                      ],
                    ),
            )
          ],
        ),
      ),
    );
  }

  Widget _moreInfoButton(double width, bool circle) {
    return SizedBox(
      width: width,
      height: 50,
      child: RaisedButton(
        child: Text(
          "More Info",
          style: TextStyle(
            color: Theme.of(context).accentColor,
            fontSize: 20,
          ),
        ),
        color: Theme.of(context).primaryColor,
        shape: circle
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(75),
              )
            : ButtonTheme.of(context).shape,
        onPressed: _showInfo,
      ),
    );
  }

  void _onSongVote(int songIndex, TrackQueueItem data, bool increase) {
    if (songIndex != 0 || _currentlyPlayingSong == null) {
      DocumentReference songDocument =
          widget.partyInfo.firebaseDocument.collection('tracks').document(data.uri);
      CollectionReference vote = increase
          ? songDocument.collection('upvotes')
          : songDocument.collection('downvotes');
      CollectionReference otherVote = increase
          ? songDocument.collection('downvotes')
          : songDocument.collection('upvotes');
      otherVote.document(widget.user.username).delete();
      vote.document(widget.user.username).get().then((snapshot) {
        snapshot.exists
            ? vote.document(widget.user.username).delete()
            : vote.document(widget.user.username).setData({});
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
    _spotifyPlayer.dispose();
  }

  void _continueParty() async {
    Track currentSong = await _spotifyPlayer.getCurrentSongPlaying();
    if (currentSong == null) {
      return;
    }
    if (currentSong.uri == _currentlyPlayingSong.uri) {
      put('https://api.spotify.com/v1/me/player/play',
          headers: {'Authorization': 'Bearer ${widget.partyInfo.owner.accessToken}'});
    } else {
      if (widget.user == widget.partyInfo.owner) {
        _spotifyPlayer.playSong(_currentlyPlayingSong);
      }
      _partyPaused = false;
    }
  }

  void _endParty() {
    // todo
    Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (context) {
          return EndPartyPage(widget.partyInfo, user: widget.user);
        }
    ));
  }

  void _issueStartPartyCommand() {
    var commandsCollection = widget.partyInfo.firebaseDocument.collection('commands');
    commandsCollection.document(START_PARTY_COMMAND).setData({});
  }

  void _startParty() async {
    markDeviceAsActive(widget.partyInfo.owner, scaffoldKey.currentState, () {
      setState(() {
        if (_queue.length >= 1) {
          _partyStarted = true;
          _currentlyPlayingSong = _queue.removeFirst();
          widget.partyInfo.songs.add(_currentlyPlayingSong);
          if (widget.user == widget.partyInfo.owner) {
            _spotifyPlayer.playSong(_currentlyPlayingSong);
          }
        }
      });
    });
  }

  void _openSearch() {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => PartyPageSearching(
            widget.partyInfo.owner, _queue, _votes, _downvotes, _addSongToDatabase)));
  }

  void _showInfo() {
    Color background = Colors.black.withOpacity(0.7);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: background,
          content: Container(
            height: MediaQuery.of(context).size.height / 2,
            child: Center(
              child: Text(
                "Party join ID: ${widget.partyInfo.id}",
                style: TextStyle(
                  fontSize: 20,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showTrackInfo(AppBar appBar, TrackQueueItem data) {
    Color background = Colors.black.withOpacity(0.7);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: background,
          content: TrackInfoView(appBar, data),
        );
      },
    );
  }
}
