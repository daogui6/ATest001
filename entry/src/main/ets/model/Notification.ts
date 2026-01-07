export type NotificationType = 'comment_like' | 'comment_reply';

export interface NotificationItem {
  id: string;
  type: NotificationType;
  articleId: number;
  articleTitle: string;
  commentId: string;
  fromUserId: string;
  fromNickname: string;
  content?: string;
  createdAt: number;
  read: boolean;
}