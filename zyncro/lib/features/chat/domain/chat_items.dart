import 'package:zyncro/features/chat/domain/entities/message.dart';

/// Élément affiché dans la liste du chat.
sealed class ChatItem {
  const ChatItem();
}

/// Un message, à l'index [index] de la liste source.
final class MessageItem extends ChatItem {
  const MessageItem(this.index);

  final int index;
}

/// Une suite d'activités de l'espace (messages système consécutifs),
/// affichée comme un seul bloc repliable. [indices] : du plus récent au plus
/// ancien, comme la liste source.
final class ActivityGroupItem extends ChatItem {
  const ActivityGroupItem(this.indices);

  final List<int> indices;
}

/// Regroupe les messages système **consécutifs** de [messages] (du plus
/// récent au plus ancien) en blocs d'au moins [minRun] activités ; une
/// activité isolée reste un message ordinaire.
List<ChatItem> groupActivity(List<Message> messages, {int minRun = 2}) {
  final items = <ChatItem>[];
  var i = 0;
  while (i < messages.length) {
    if (messages[i].type != MessageType.system) {
      items.add(MessageItem(i));
      i++;
      continue;
    }
    final run = <int>[];
    while (i < messages.length && messages[i].type == MessageType.system) {
      run.add(i);
      i++;
    }
    if (run.length >= minRun) {
      items.add(ActivityGroupItem(run));
    } else {
      items.addAll(run.map(MessageItem.new));
    }
  }
  return items;
}
