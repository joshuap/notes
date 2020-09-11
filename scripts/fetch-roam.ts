/*
MIT License

Copyright (c) 2020 Mathieu Dutour

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

import puppeteer from "puppeteer";
import * as path from "path";
import * as fs from "fs";
import watch from "node-watch";
import * as unzipper from "unzipper";

enum LOGIN_STATE {
  NEED,
  IN,
}

type Reporter = {
  info(log: string): void;
};

const topBarMoreSelector = `.roam-topbar .bp3-icon-more`;

async function click(page: puppeteer.Page, xpath: string) {
  await page.waitForXPath(xpath);
  const [button] = await page.$x(xpath);
  if (!button) {
    throw new Error(`Button "${xpath}" not found`);
  }

  await button.click();
}

function sleep(time: number = 1000) {
  return new Promise((resolve) => setTimeout(resolve, time));
}

async function checkLogin(
  page: puppeteer.Page,
  auth: {
    email: string;
    password: string;
  },
  options?: {
    reporter?: Reporter;
    debug?: boolean;
  }
) {
  const state = await Promise.race([
    page
      .waitForSelector('input[name="email"]')
      .then(() => LOGIN_STATE.NEED)
      .catch(() => LOGIN_STATE.NEED),
    page
      .waitForSelector(topBarMoreSelector)
      .then(() => LOGIN_STATE.IN)
      .catch(() => LOGIN_STATE.NEED),
  ]);

  if (state === LOGIN_STATE.NEED) {
    options?.reporter?.info("Login into Roam Research...");
    await page.type('input[name="email"]', auth.email);
    await page.type('input[name="password"]', auth.password);
    const [loginButton] = await page.$x("//button[text()='Sign In']");
    if (!loginButton) {
      throw new Error("Login Button not found");
    }
    await loginButton.click();
    await sleep();

    // check for login until we are fine
    await checkLogin(page, auth);
  }
}

const downloadRoam = async (
  url: string,
  auth: {
    email: string;
    password: string;
  },
  options?: {
    reporter?: Reporter;
    puppeteer?: puppeteer.LaunchOptions;
    debug?: boolean;
  }
): Promise<undefined> => {
  const downloadPath = path.join(__dirname, '../db', `${Date.now()}`);
  await fs.promises.mkdir(downloadPath, { recursive: true });

  if (options?.debug) {
    options.reporter?.info(`created cache dir ${downloadPath}`);
  }

  const zipCreationPromise = new Promise<string>((resolve, reject) => {
    const watcher = watch(
      downloadPath,
      { filter: /\.zip$/ },
      (eventType: "update" | "remove", filename: string) => {
        if (eventType == "update") {
          watcher.close();
          resolve(filename);
        }
      }
    );
  });

  // disable sandbox in production
  const browser = await puppeteer.launch({
    args: process.env.NODE_ENV === "production" ? ["--no-sandbox"] : [],
    ...(options?.puppeteer || {}),
  });

  try {
    const page = await browser.newPage();
    const cdp = await page.target().createCDPSession();
    cdp.send("Page.setDownloadBehavior", {
      behavior: "allow",
      downloadPath,
    });

    await page.goto(url);

    if (options?.debug) {
      options.reporter?.info(`opening ${url}`);
    }

    await checkLogin(page, auth, options);

    await page.click(topBarMoreSelector);

    await click(page, "//div[text()='Export All']");
    await click(page, "//span[text()='Markdown']");
    await click(page, "//div[text()='JSON']");

    options?.reporter?.info("Downloading Roam Research database...");

    await click(page, "//button[text()='Export All']");
    const zipPath = await zipCreationPromise;

    await browser.close();

    await unzipper.Open.file(zipPath)
      .then(d => d.extract({ path: path.join(__dirname, '../db'), concurrency: 5 }));

    await fs.promises.unlink(zipPath);
    await fs.promises.rmdir(downloadPath);
  } catch (err) {
    console.error(err);
    await browser.close();
    return undefined;
  }
};

downloadRoam(String(process.env.ROAM_URL), {
  email: String(process.env.ROAM_EMAIL),
  password: String(process.env.ROAM_PASSWORD),
}, {
  reporter: console
});