/**
 * @jest-environment jsdom
 */

import fs from "fs"
import path from "path"
import vm from "vm"

const loadAdSenseScriptBody = () => {
  const filePath = path.join(__dirname, "../../app/views/shared/_meta_tags.html.erb")
  const content = fs.readFileSync(filePath, "utf8")
  const match = content.match(/<!-- Google AdSense \(load after consent\) -->[\s\S]*?<script[^>]*>([\s\S]*?)<\/script>/)

  if (!match) {
    throw new Error("AdSense script block not found in _meta_tags.html.erb")
  }

  const scriptBody = match[1]
  const cleaned = scriptBody.startsWith("\">")
    ? scriptBody.slice(2).trimStart()
    : scriptBody.trimStart()

  return cleaned
}

const executeScript = (scriptBody, sandbox) => {
  const context = vm.createContext(sandbox)
  vm.runInContext(scriptBody, context)
  return context
}

describe("AdSense consent auto-load script", () => {
  let scriptBody

  beforeAll(() => {
    scriptBody = loadAdSenseScriptBody()
  })

  test("localStorage が利用できなくても例外を投げずにスキップする", () => {
    const appendChild = jest.fn()
    const warn = jest.fn()
    const sandbox = {
      window: {},
      document: {
        createElement: jest.fn().mockReturnValue({}),
        head: { appendChild }
      },
      localStorage: {
        getItem: () => {
          const error = new Error("blocked")
          error.name = "SecurityError"
          throw error
        }
      },
      console: { warn }
    }

    expect(() => executeScript(scriptBody, sandbox)).not.toThrow()
    expect(appendChild).not.toHaveBeenCalled()
    expect(sandbox.window.__adsenseLoaded).toBeUndefined()
    expect(warn).toHaveBeenCalledWith(
      "AdSense auto-load skipped: localStorage unavailable",
      expect.any(Error)
    )
  })

  test("同意済みなら自動的にAdSenseを読み込む", () => {
    const appendChild = jest.fn()
    const sandbox = {
      window: {},
      document: {
        createElement: jest.fn().mockReturnValue({}),
        head: { appendChild }
      },
      localStorage: {
        getItem: jest.fn().mockReturnValue("granted")
      }
    }

    executeScript(scriptBody, sandbox)

    expect(appendChild).toHaveBeenCalledTimes(1)
  })

  test("同意が未取得ならAdSenseを読み込まない", () => {
    const appendChild = jest.fn()
    const sandbox = {
      window: {},
      document: {
        createElement: jest.fn().mockReturnValue({}),
        head: { appendChild }
      },
      localStorage: {
        getItem: jest.fn().mockReturnValue(null)
      },
      console: { warn: jest.fn() }
    }

    executeScript(scriptBody, sandbox)

    expect(appendChild).not.toHaveBeenCalled()
    expect(sandbox.window.__adsenseLoaded).toBeUndefined()
  })
})

