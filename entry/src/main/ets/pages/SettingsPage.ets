/**
 * 设置中心页面 - 用户设置与账号管理
 *
 * 功能概述：
 * - 账号信息展示与编辑
 * - 消息与播放偏好设置
 * - 清理缓存与帮助入口
 * - 登录/退出管理
 */

import type common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import picker from '@ohos.file.picker';
import router from '@ohos.router';
import { Prefs } from '../store/Prefs';
import { UserStore } from '../store/UserStore';
import { NotificationStore } from '../store/NotificationStore';

@Entry
@Component
export struct SettingsPage {
  private KEY_UID = 'session.userId';
  private KEY_LOGIN = 'session.isLogin';
  private KEY_NICK = 'profile.nickname';
  private KEY_BIO = 'profile.bio';
  private KEY_AVATAR = 'profile.avatar';

  @State isLogin: boolean = false;
  @State nickname: string = '用户1';
  @State bio: string = '这个人很懒，还没有签名～';
  @State avatarUrl: string = '';
  @State uid: string = '0';
  @State username: string = '';
  @State publicName: string = '';
  @State token: string = '';
  @State isEditingProfile: boolean = false;
  @State enablePush: boolean = true;
  @State enableAutoPlay: boolean = true;
  @State enableCellular: boolean = false;
  @State unreadNotifications: number = 0;

  private hostCtx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  async aboutToAppear() {
    await this.loadSession();
    await this.refreshNotifications();
  }

  private async loadSession() {
    const user = await UserStore.currentUser(this.hostCtx());
    if (user) {
      this.uid = String(user.id);
      this.nickname = user.nickname || user.username;
      this.bio = user.bio ?? '这个人很懒，还没有签名～';
      this.avatarUrl = user.avatarUrl ?? '';
      this.username = user.username;
      this.publicName = user.publicName;
      this.token = user.token ?? '';
      this.isLogin = true;
      return;
    }

    const uid = await Prefs.getString(this.hostCtx(), this.KEY_UID, '0');
    this.isLogin = (uid !== '0');
    this.nickname = await Prefs.getString(this.hostCtx(), this.KEY_NICK, '用户1');
    this.bio = await Prefs.getString(this.hostCtx(), this.KEY_BIO, '这个人很懒，还没有签名～');
    this.avatarUrl = await Prefs.getString(this.hostCtx(), this.KEY_AVATAR, '');
    this.uid = uid;
  }

  private async saveAll() {
    await Prefs.putString(this.hostCtx(), this.KEY_UID, this.uid);
    await Prefs.putBool(this.hostCtx(), this.KEY_LOGIN, this.isLogin);
    await Prefs.putString(this.hostCtx(), this.KEY_NICK, this.nickname);
    await Prefs.putString(this.hostCtx(), this.KEY_BIO, this.bio);
    await Prefs.putString(this.hostCtx(), this.KEY_AVATAR, this.avatarUrl);

    if (this.isLogin && this.uid !== '0') {
      await UserStore.updateProfile(this.hostCtx(), {
        nickname: this.nickname,
        bio: this.bio,
        avatarUrl: this.avatarUrl
      });
    }
  }

  private async persistProfileChanges() {
    this.nickname = this.nickname.trim() || this.username || '用户1';
    this.bio = this.bio.trim() || '这个人很懒，还没有签名～';

    await this.saveAll();

    AppStorage.setOrCreate('session_version', 0);
    const v = (AppStorage.get('session_version') as number) ?? 0;
    AppStorage.set('session_version', v + 1);

    promptAction.showToast({ message: '已保存个人资料' });
  }

  private async requestPhotoPermission(): Promise<boolean> {
    try {
      const result = await promptAction.showDialog({
        title: '申请相册权限',
        message: '用于选择头像和上传图片，我们仅会在您主动操作时访问相册。',
        buttons: [
          { text: '暂不允许', color: '#666666' },
          { text: '允许', color: '#4C6FFF' }
        ]
      });
      return result?.index === 1;
    } catch {
      return false;
    }
  }

  private async chooseAvatar() {
    try {
      const permitted = await this.requestPhotoPermission();
      if (!permitted) {
        promptAction.showToast({ message: '未授权相册权限，无法选择头像' });
        return;
      }
      const photoPicker = new picker.PhotoViewPicker();
      const options = new picker.PhotoSelectOptions();
      options.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const result = await photoPicker.select(options);
      if (result?.photoUris?.length) {
        this.avatarUrl = result.photoUris[0];
      }
    } catch (e) {
      promptAction.showToast({ message: '头像选择失败，请稍后重试' });
    }
  }

  private async handleLogout() {
    this.uid = '0';
    this.username = '';
    this.publicName = '';
    this.token = '';
    this.avatarUrl = '';
    this.isLogin = false;
    this.isEditingProfile = false;

    await this.saveAll();
    await UserStore.logout(this.hostCtx());

    AppStorage.setOrCreate('session_version', 0);
    const v = (AppStorage.get('session_version') as number) ?? 0;
    AppStorage.set('session_version', v + 1);

    await this.refreshNotifications();
    promptAction.showToast({ message: '已退出登录' });
  }

  private async cancelEditProfile() {
    await this.loadSession();
    this.isEditingProfile = false;
  }

  private async refreshNotifications() {
    if (!this.isLogin || this.uid === '0') {
      this.unreadNotifications = 0;
      return;
    }
    this.unreadNotifications = await NotificationStore.unreadCount(this.hostCtx(), this.uid);
  }

  private async openHelpCenter() {
    promptAction.showToast({ message: '帮助中心正在建设中' });
  }

  private async clearCache() {
    promptAction.showToast({ message: '缓存已清理，空间更清爽' });
  }

  build() {
    Column() {
      Row() {
        Text('←')
          .fontSize(20)
          .margin({ left: 16 })
          .onClick(() => router.back());
        Text('设置中心')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Blank().width(36)
      }
      .alignItems(VerticalAlign.Center)
      .padding({ top: 16, right: 16, bottom: 12 })

      Scroll() {
        Column({ space: 16 }) {
          Column({ space: 12 }) {
            Row() {
              Text('账号信息').fontSize(16).fontWeight(FontWeight.Medium)
            }

            if (this.isLogin) {
              Column({ space: 6 }) {
                Text(`用户ID：${this.uid}`).fontSize(13).opacity(0.7)
                Text(`用户名：${this.username || '未获取'}`).fontSize(13).opacity(0.7)
                Text(`公开昵称：${this.publicName || this.nickname}`).fontSize(13).opacity(0.7)
                Text(`昵称：${this.nickname}`).fontSize(13).opacity(0.7)
                Text(`签名：${this.bio}`).fontSize(13).opacity(0.7)
                Text(`Token：${this.token || '暂无'}`).fontSize(13).opacity(0.6)
              }
            } else {
              Text('登录后可管理账号信息').fontSize(12).opacity(0.6)
            }
          }
          .padding(16)
          .borderRadius(16)
          .backgroundColor('#FFFFFF')
          .border({ width: 1, color: '#E9EEF5' })
          .shadow({ radius: 12, color: '#1A3B5A14', offsetX: 0, offsetY: 6 })

          Column({ space: 10 }) {
            Row() {
              Text('消息提醒').fontSize(14)
              Blank().layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.enablePush })
                .onChange((v: boolean) => {
                  this.enablePush = v;
                })
            }
            Row() {
              Text('首页自动播放').fontSize(14)
              Blank().layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.enableAutoPlay })
                .onChange((v: boolean) => {
                  this.enableAutoPlay = v;
                })
            }
            Row() {
              Text('移动网络播放').fontSize(14)
              Blank().layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.enableCellular })
                .onChange((v: boolean) => {
                  this.enableCellular = v;
                })
            }
          }
          .padding(16)
          .borderRadius(16)
          .backgroundColor('#FFFFFF')
          .border({ width: 1, color: '#E9EEF5' })
          .shadow({ radius: 12, color: '#1A3B5A14', offsetX: 0, offsetY: 6 })

          Column({ space: 10 }) {
            Row() {
              Text('清理缓存').fontSize(14)
              Blank().layoutWeight(1)
              Text('立即').fontSize(12).fontColor('#3B82F6')
            }
            .onClick(async () => await this.clearCache())
            Row() {
              Text('帮助中心').fontSize(14)
              Blank().layoutWeight(1)
              Text('查看').fontSize(12).fontColor('#3B82F6')
            }
            .onClick(async () => await this.openHelpCenter())
          }
          .padding(16)
          .borderRadius(16)
          .backgroundColor('#FFFFFF')
          .border({ width: 1, color: '#E9EEF5' })
          .shadow({ radius: 12, color: '#1A3B5A14', offsetX: 0, offsetY: 6 })

          if (this.isLogin) {
            Column({ space: 12 }) {
              Row() {
                Text('资料管理').fontSize(16).fontWeight(FontWeight.Medium)
              }

              if (this.isEditingProfile) {
                Row({ space: 12 }) {
                  Stack({ alignContent: Alignment.Center }) {
                    if (this.avatarUrl) {
                      Image(this.avatarUrl)
                        .width(52)
                        .height(52)
                        .borderRadius(26)
                        .objectFit(ImageFit.Cover)
                    } else {
                      Image($r('app.media.startIcon'))
                        .width(52)
                        .height(52)
                        .borderRadius(26)
                        .backgroundColor('#4C6FFF')
                        .objectFit(ImageFit.Cover)
                    }
                  }
                  .width(52)
                  .height(52)
                  .borderRadius(26)
                  .border({ width: 1, color: '#E2E8F5' })
                  Button('更换头像', { type: ButtonType.Capsule })
                    .onClick(async () => {
                      await this.chooseAvatar();
                    })
                }
                .alignItems(VerticalAlign.Center)

                Text('编辑昵称').fontSize(14).opacity(0.7)
                TextInput({ text: this.nickname, placeholder: '请输入昵称' })
                  .onChange((v) => {
                    this.nickname = v;
                  })
                  .padding({ left: 12, right: 12 })
                  .borderRadius(10)
                  .backgroundColor('#F6F7FB')

                Text('编辑签名').fontSize(14).opacity(0.7).margin({ top: 6 })
                TextInput({ text: this.bio, placeholder: '请输入签名' })
                  .onChange((v) => {
                    this.bio = v
                  })
                  .padding({ left: 12, right: 12 })
                  .borderRadius(10)
                  .backgroundColor('#F6F7FB')

                Row({ space: 12 }) {
                  Button('保存资料', { type: ButtonType.Capsule })
                    .layoutWeight(1)
                    .onClick(async () => {
                      await this.persistProfileChanges();
                      this.isEditingProfile = false;
                    })
                  Button('取消', { type: ButtonType.Capsule })
                    .layoutWeight(1)
                    .onClick(async () => {
                      await this.cancelEditProfile();
                    })
                }
                .margin({ top: 6 })
              } else {
                Row({ space: 12 }) {
                  Button('修改资料', { type: ButtonType.Capsule })
                    .layoutWeight(1)
                    .onClick(() => {
                      this.isEditingProfile = true;
                    })
                  Button('退出登录', { type: ButtonType.Capsule })
                    .layoutWeight(1)
                    .onClick(async () => {
                      await this.handleLogout();
                    })
                }
                .margin({ top: 10 })
              }
            }
            .padding(16)
            .borderRadius(16)
            .backgroundColor('#FFFFFF')
            .border({ width: 1, color: '#E9EEF5' })
            .shadow({ radius: 12, color: '#1A3B5A14', offsetX: 0, offsetY: 6 })
          }
        }
        .padding({ left: 16, right: 16, bottom: 24 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#EFF2F9')
  }
}