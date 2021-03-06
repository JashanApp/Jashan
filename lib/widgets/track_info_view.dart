import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:jashan/data/track_queue_item.dart';
import 'package:jashan/util/text_utilities.dart';

class TrackInfoView extends StatelessWidget {
  final TrackQueueItem data;
  final AppBar appBar;

  TrackInfoView(this.appBar, this.data);

  @override
  Widget build(BuildContext context) {
    final double height = MediaQuery.of(context).size.height -
        appBar.preferredSize.height -
        MediaQuery.of(context).padding.top -
        kToolbarHeight;
    String upvotes = "";
    if (data.upvotes.isNotEmpty) {
      data.upvotes.forEach((user) {
        upvotes += "${user}, ";
      });
      upvotes = upvotes.substring(0, upvotes.length - 2);
    }
    String downvotes = "";
    if (data.downvotes.isNotEmpty) {
      data.downvotes.forEach((user) {
        downvotes += "$user, ";
      });
      downvotes = downvotes.substring(0, downvotes.length - 2);
    }
    return Container(
      width: MediaQuery.of(context).size.width,
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            "${getTextWithCap(data.title, 21)}",
            style: TextStyle(
              fontSize: 20,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.5),
            child: Text(
              "Added by: ${data.addedBy}",
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          Divider(
            color: Theme.of(context).accentColor,
          ),
          data.upvotes.length != 0
              ? _VoteDescriptionWidget(
                  "upvotes",
                  Icons.keyboard_arrow_up,
                  amount: data.upvotes.length,
                  who: upvotes,
                )
              : Container(),
          data.downvotes.length != 0
              ? _VoteDescriptionWidget(
                  "downvotes",
                  Icons.keyboard_arrow_down,
                  amount: data.downvotes.length,
                  who: downvotes,
                )
              : Container(),
        ],
      ),
    );
  }
}

class _VoteDescriptionWidget extends StatelessWidget {
  final int amount;
  final String who;
  final String voteType;
  final IconData icon;

  _VoteDescriptionWidget(this.voteType, this.icon,
      {this.amount, this.who});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        children: <Widget>[
          Icon(
            icon,
            color: Theme.of(context).primaryColor,
            size: 36,
          ),
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.05,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                "$amount reacted with $voteType:",
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).accentColor,
                ),
              ),
              Text(who),
            ],
          ),
        ],
      ),
    );
  }
}
