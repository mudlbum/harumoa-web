import XCTest
import WebKit
@testable import Harumoa

@MainActor
final class HarumoaTests: XCTestCase {
    var shell: HarumoaViewController { (UIApplication.shared.delegate as! AppDelegate).window!.rootViewController as! HarumoaViewController }
    func js(_ code: String) async throws -> Any { try await shell.web.evaluateJavaScript(code) }
    func wait(_ expression: String) async throws {
        for _ in 0..<100 {
            if (try? await js(expression) as? Bool) == true { return }
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        XCTFail("Bundled WKWebView did not become ready: " + expression)
        throw URLError(.timedOut)
    }
    func testRealWKWebViewDraftAndStorage() async throws {
        try await wait("typeof Harumoa !== 'undefined' && !!document.querySelector('[data-hm=demo-start]')")
        _ = try await js("localStorage.setItem('hm.audience.v1', JSON.stringify({band:'18+',country:'KR'}));document.querySelector('[data-hm=demo-start]').click();true")
        try await wait("!!document.querySelector('.top-actions')")
        _ = try await js("document.querySelector('#quick-add-root button').click();true")
        try await wait("!!document.querySelector('#composer[open] [name=title]')")
        _ = try await js("const t=document.querySelector('#composer [name=title]');t.value='iOS restart draft';t.dispatchEvent(new Event('input',{bubbles:true}));true")
        let persisted = try await js("Object.entries(localStorage).some(([k,v])=>k.startsWith('hm.drafts.v1.')&&v.includes('iOS restart draft'))") as? Bool
        XCTAssertEqual(persisted, true)
        shell.web.reload()
        try await Task.sleep(nanoseconds: 500_000_000)
        try await wait("!!document.querySelector('[data-hm=demo-start]')")
        _ = try await js("document.querySelector('[data-hm=demo-start]').click();true")
        try await wait("!!document.querySelector('.top-actions')")
        _ = try await js("document.querySelector('#quick-add-root button').click();true")
        try await wait("!!document.querySelector('#composer[open] [name=title]')")
        let restored = try await js("document.querySelector('#composer [name=title]').value") as? String
        XCTAssertEqual(restored, "iOS restart draft")
        _ = try await js("document.querySelector('#composer [type=submit]').click();true")
        try await wait("!document.querySelector('#composer').open && !Harumoa.state.busy")
        let saved = try await js("Harumoa.state.data.activities.some(a=>a.title==='iOS restart draft')") as? Bool
        XCTAssertEqual(saved, true)
        // Real custom-origin IndexedDB, not an in-memory storage substitute.
        let count = try await shell.web.callAsyncJavaScript("const r=indexedDB.open('ios-native-test',1);r.onupgradeneeded=()=>r.result.createObjectStore('pending');const db=await new Promise((ok,no)=>{r.onsuccess=()=>ok(r.result);r.onerror=()=>no(r.error)});const t=db.transaction('pending','readwrite');t.objectStore('pending').put('durable','one');await new Promise((ok,no)=>{t.oncomplete=ok;t.onerror=()=>no(t.error)});const g=db.transaction('pending').objectStore('pending').get('one');const value=await new Promise((ok,no)=>{g.onsuccess=()=>ok(g.result);g.onerror=()=>no(g.error)});db.close();return value;", arguments: [:], in: nil, contentWorld: .page)
        XCTAssertEqual(count as? String, "durable")
    }
    func testTrustedBridgeAndMissingGoogleConfig() async throws {
        try await wait("typeof HarumoaGoogle === 'object'")
        XCTAssertTrue(Assets.local(URL(string: "harumoa://localhost/index.html")))
        XCTAssertFalse(Assets.local(URL(string: "https://mudlbum.github.io/harumoa-web/")))
        XCTAssertFalse(Assets.local(URL(string: "harumoa://evil/index.html")))
        XCTAssertFalse(Assets.local(URL(string: "harumoa://localhost:8080/index.html")))
        let result = try await shell.web.callAsyncJavaScript("const id=crypto.randomUUID();return await new Promise((ok,no)=>{const timer=setTimeout(()=>no(new Error('native IPC did not reply')),5000);const listener=e=>{if(e.detail.requestId!==id)return;clearTimeout(timer);window.removeEventListener('harumoa:google-auth',listener);ok(e.detail.error)};window.addEventListener('harumoa:google-auth',listener);HarumoaGoogle.signIn(id)});", arguments: [:], in: nil, contentWorld: .page)
        XCTAssertEqual(result as? String, "ios_oauth_missing")
    }
    func testNativeRecordingAndLocalRead() async throws {
        try await wait("typeof HarumoaRecorder === 'object'")
        let result = try await shell.web.callAsyncJavaScript("const id=crypto.randomUUID();const data=await new Promise((ok,no)=>{const timer=setTimeout(()=>no(new Error('recording timed out')),15000);let stopped=false;const listener=e=>{const d=e.detail;if(d.requestId!==id)return;if(d.phase==='recording'&&!stopped){stopped=true;setTimeout(()=>HarumoaRecorder.stop(id),900)}else if(d.phase==='finished'||d.phase==='error'){clearTimeout(timer);window.removeEventListener('harumoa:recording',listener);d.phase==='finished'?ok(d):no(new Error(d.message))}};window.addEventListener('harumoa:recording',listener);HarumoaRecorder.start(id)});const response=await fetch(data.url);const bytes=(await response.blob()).size;HarumoaRecorder.discardFile(data.token);return {bytes,mime:data.mime,url:data.url};", arguments: [:], in: nil, contentWorld: .page)
        let fields = try XCTUnwrap(result as? [String: Any])
        XCTAssertEqual(fields["mime"] as? String, "audio/mp4")
        XCTAssertGreaterThan(fields["bytes"] as? Int ?? 0, 0)
        XCTAssertTrue((fields["url"] as? String ?? "").hasPrefix("harumoa://localhost/recordings/"))
    }
}
