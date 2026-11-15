
import { FlutterAbility, FlutterEngine, MethodChannel, MethodCall, MethodCallHandler, MethodResult } from '@ohos/flutter_ohos';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import picker from '@ohos.file.picker';
import fs from '@ohos.file.fs';
import dataPreferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';

class HostHandler implements MethodCallHandler {
  private ctx: common.UIAbilityContext;

  constructor(ctx: common.UIAbilityContext) {
    this.ctx = ctx;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    if (call.method === 'pickImage') {
      this.pickImage(result);
    } else if (call.method === 'saveImage') {
      this.saveImage(call, result);
    } else if (call.method === 'loadLocal') {
      this.loadLocal(result);
    } else if (call.method === 'writeLocal') {
      this.writeLocal(call, result);
    } else if (call.method === 'removeLocal') {
      this.removeLocal(call, result);
    } else if (call.method === 'exitApp') {
      this.ctx.terminateSelf();
    } else {
      result.notImplemented();
    }
  }

  /** 相册选图：PhotoViewPicker 是系统安全组件，无需任何权限。 */
  private pickImage(result: MethodResult): void {
    const photoPicker = new picker.PhotoViewPicker();
    const options: picker.PhotoSelectOptions = {
      MIMEType: picker.PhotoViewMIMETypes.IMAGE_TYPE,
      maxSelectNumber: 1,
    };
    photoPicker.select(options).then((res: picker.PhotoSelectResult) => {
      const uris: string[] = res.photoUris;
      if (!uris || uris.length === 0) {
        result.success(null);
        return;
      }
      const file = fs.openSync(uris[0], fs.OpenMode.READ_ONLY);
      try {
        const stat = fs.statSync(file.fd);
        const buf = new ArrayBuffer(stat.size);
        fs.readSync(file.fd, buf);
        result.success(new Uint8Array(buf));
      } finally {
        fs.closeSync(file);
      }
    }).catch(() => {
      result.success(null);
    });
  }

  /** 导出图片：DocumentViewPicker 另存为（用户选位置），同样零权限。 */
  private saveImage(call: MethodCall, result: MethodResult): void {
    const bytes = call.argument('bytes') as Uint8Array;
    const filename = call.argument('name') as string;
    if (!bytes || !filename) {
      result.success('保存失败：参数缺失');
      return;
    }
    const docPicker = new picker.DocumentViewPicker();
    const options: picker.DocumentSaveOptions = {
      newFileNames: [filename],
    };
    docPicker.save(options).then((uris: string[]) => {
      if (!uris || uris.length === 0) {
        result.success('未保存');
        return;
      }
      const file = fs.openSync(uris[0],
        fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      try {
        fs.writeSync(file.fd, bytes.buffer);
        result.success('已保存：' + uris[0]);
      } finally {
        fs.closeSync(file);
      }
    }).catch(() => {
      result.success('保存失败，请重试');
    });
  }

  private getPrefs(): Promise<dataPreferences.Preferences> {
    return dataPreferences.getPreferences(this.ctx, { name: 'avatar_store' });
  }

  /** 启动时把持久层全部键值交给 Flutter 内存层。 */
  private loadLocal(result: MethodResult): void {
    this.getPrefs().then((prefs) => {
      const all = prefs.getAllSync() as Record<string, dataPreferences.ValueType>;
      const map = new Map<string, string>();
      for (const k of Object.keys(all)) {
        const v = all[k];
        if (v != null) {
          map.set(k, String(v));
        }
      }
      result.success(map);
    }).catch(() => {
      result.success(null);
    });
  }

  private writeLocal(call: MethodCall, result: MethodResult): void {
    const key = call.argument('key') as string;
    const value = call.argument('value') as string;
    this.getPrefs().then((prefs) => {
      prefs.putSync(key, value);
      prefs.flush();
      result.success(null);
    }).catch(() => {
      result.success(null);
    });
  }

  private removeLocal(call: MethodCall, result: MethodResult): void {
    const key = call.argument('key') as string;
    this.getPrefs().then((prefs) => {
      prefs.deleteSync(key);
      prefs.flush();
      result.success(null);
    }).catch(() => {
      result.success(null);
    });
  }
}

export default class EntryAbility extends FlutterAbility {
  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    GeneratedPluginRegistrant.registerWith(flutterEngine)
    const channel = new MethodChannel(flutterEngine.dartExecutor.getBinaryMessenger(), 'avatar.host');
    channel.setMethodCallHandler(new HostHandler(this.context));
  }
}
