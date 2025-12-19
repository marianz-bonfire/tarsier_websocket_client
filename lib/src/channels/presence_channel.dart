import '../models/collection.dart';
import '../models/member.dart';
import 'private_channel.dart';

/// Represents a presence channel in Pusher.
///
/// A presence channel extends the functionality of a private channel by
/// keeping track of members subscribed to the channel. It allows for member
/// events, such as when a member joins or leaves the channel.
class PresenceChannel extends PrivateChannel {
  /// Creates an instance of [PresenceChannel].
  ///
  /// The [client] parameter specifies the Pusher client, and [name] specifies
  /// the name of the channel.
  PresenceChannel({
    required super.client,
    required super.name,
  }) {
    onMemberAdded(_onMemberAdd);
    onMemberRemoved(_onMemberRemove);
  }

  /// Binds a callback to the member added event.
  ///
  /// The [callback] parameter is invoked whenever a new member joins the channel.
  void onMemberAdded(Function callback) =>
      bind('pusher:member_added', callback);

  /// Binds a callback to the member removed event.
  ///
  /// The [callback] parameter is invoked whenever a member leaves the channel.
  void onMemberRemoved(Function callback) =>
      bind('pusher:member_removed', callback);

  /// The current user's member information in the channel.
  ///
  /// If the user's ID is available, this returns the associated [Member] object.
  /// Otherwise, it returns `null`.
  @override
  Member? get member =>
      userId != null ? _members.get(userId!) ?? Member(id: userId!) : null;

  /// A collection of all members currently in the channel.
  ///
  /// Returns a list of [Member] objects representing all members in the channel.
  List<Member> get members => _members.all();

  /// Internal handler for the member added event.
  ///
  /// Adds a new [Member] to the channel's members collection when the
  /// `pusher:member_added` event is triggered.
  void _onMemberAdd(Map data) {
    options.log("MEMBER_ADDED", channel: name, data: "member: $data");

    final member = Member.fromMap(data);
    _members.add(member.id, Member.fromMap(data), override: true);
  }

  /// Internal handler for the member removed event.
  ///
  /// Removes a [Member] from the channel's members collection when the
  /// `pusher:member_removed` event is triggered.
  void _onMemberRemove(Map data) {
    options.log("MEMBER_REMOVED", channel: name, data: "member: $data");

    final id = data["user_id"] ?? data["id"];

    if (id != null) _members.remove(id);
  }

  /// A private collection of members in the channel.
  ///
  /// This collection stores and manages the state of all members in the channel.
  final _members = Collection<Member>();
}
