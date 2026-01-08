/*
 * Comment.ts - 评论数据模型接口
 * 
 * 功能说明：
 * - 定义评论数据的结构和类型
 * - 支持评论和回复功能
 * - 包含用户信息和时间戳
 * 
 * 数据字段说明：
 * - id: 评论唯一标识
 * - articleId: 关联的文章ID
 * - userId: 评论用户ID
 * - nickname: 用户昵称
 * - content: 评论内容
 * - createdAt: 评论创建时间戳
 * - parentId: 父评论ID（可选，用于回复）
 * - replyTo: 回复目标用户昵称（可选）
 */

/**
 * 评论数据模型接口
 * 
 * 表示一条评论或回复，包含评论内容和用户信息
 * 支持多级回复功能
 */
export interface Comment {
  /**
   * 评论唯一标识符
   * 用于区分不同评论，通常由后端生成
   */
  id: string;

  /**
   * 关联的文章ID
   * 指向该评论所属的文章
   * 与Article接口的id字段对应
   */
  articleId: number;

  /**
   * 评论用户ID
   * 发表评论的用户唯一标识
   */
  userId: string;

  /**
   * 用户昵称
   * 显示在评论中的用户名称
   */
  nickname: string;

  /**
   * 评论内容
   * 用户发表的评论文本
   */
  content: string;

  /**
   * 评论创建时间戳
   * 毫秒级时间戳，表示评论发表时间
   * 用于评论排序和时间显示
   */
  createdAt: number;

  /**
   * 父评论ID
   * 可选字段，用于回复功能
   * 为空时表示顶级评论
   */
  parentId?: string;

  /**
   * 回复目标用户昵称
   * 可选字段，表示回复的用户昵称
   * 用于显示"回复@用户名"的格式
   */
  replyTo?: string;
}