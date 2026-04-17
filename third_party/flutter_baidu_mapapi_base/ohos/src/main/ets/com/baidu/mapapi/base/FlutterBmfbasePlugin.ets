import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';
import { Initializer, CoordType } from '@bdmap/base';
import { bundleManager, common } from '@kit.AbilityKit';

const METHOD_SET_API_KEY: string = "flutter_bmfbase/sdk/setApiKey";

/** FlutterBmfbasePlugin **/
export default class FlutterBmfbasePlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;
  private sContext: common.Context | null = null

  constructor() {
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.sContext = binding.getApplicationContext()
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'flutter_bmfbase')
    this.channel.setMethodCallHandler(this)
  }


  onMethodCall(call: MethodCall, result: MethodResult): void {
    // 接受Dart侧发来的消息
    let method: string = call.method
    if (method == METHOD_SET_API_KEY) {
      // this.getBundleAppIdentifier()
      if (this.sContext && call.hasArgument("apiKey")) {
        let ak: string = call.argument('apiKey')
        // 初始化
        Initializer.getInstance().initialize(ak, this.sContext as common.UIAbilityContext);
      }
      if (call.hasArgument("BMF_COORD_TYPE")) {
        let index = call.argument('BMF_COORD_TYPE') as number
        if (index == 1) {
          Initializer.coordType = CoordType.GCJ02
        } else if (index == 2) {
          Initializer.coordType = CoordType.BD09LL
        }
      }
    } else {
      result.notImplemented()
    }
  }

  /**
   * 获取appIdentifier
   */
  getBundleAppIdentifier(): void {
    // 根据给定的bundle名称获取BundleInfo。
    // 使用此方法需要申请 ohos.permission.GET_BUNDLE_INFO权限。
    let bundleFlags: number = bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_SIGNATURE_INFO;
    try {
      bundleManager.getBundleInfoForSelf(bundleFlags).then((data) => {
        //获取appIdentifier
        let appIdentifier = data.signatureInfo.appIdentifier;
        console.info('getBundleAppIdentifier successfully. Data: ' + appIdentifier);
      })
    } catch (error) {
      console.error('getBundleAppIdentifier failed:' + error.message);
    }
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel) {
      this.channel.setMethodCallHandler(null)
    }
  }

  getUniqueClassName(): string {
    return "FlutterBmfbasePlugin"
  }
}