# -*- coding: utf-8 -*-
"""
问道长生：Agent Bridge 真人式自动游玩驱动

这个脚本不直接改玩家数值，而是通过游戏已经预留的
WENDAO_AGENT_STATE / WENDAO_AGENT_COMMAND 接口读取状态、写入命令，
让游戏真实走菜单、修炼、历练、事件选择、突破、存档等状态机。
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Dict, List, Optional

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

HEAVENLY_DAO_INDEX = 20
DAO_ANCESTOR_INDEX = 19
MAX_STEPS = int(os.environ.get("WENDAO_AGENT_MAX_STEPS", "5000"))
MAX_SECONDS = int(os.environ.get("WENDAO_AGENT_MAX_SECONDS", "1800"))
POLL_SECONDS = float(os.environ.get("WENDAO_AGENT_POLL_SECONDS", "0.20"))


def now() -> str:
    return time.strftime("%Y-%m-%d %H:%M:%S")


class AgentDriver:
    def __init__(self, release_dir: Path) -> None:
        self.release_dir = release_dir.resolve()
        self.exe = self.release_dir / "wendao_enhanced.exe"
        self.state_path = self.release_dir / "agent_state.json"
        self.command_path = self.release_dir / "agent_command.txt"
        self.trace_path = self.release_dir / "agent_trace.log"
        self.report_path = self.release_dir / "agent_playthrough_report.txt"
        self.proc: Optional[subprocess.Popen[Any]] = None
        self.command_seq = 0
        self.last_realm_index = -1
        self.last_realm_step = 0
        self.last_player_fingerprint = ""
        self.same_fingerprint_ticks = 0
        self.heavenly_reached = False
        self.saved_at_heavenly = False
        self.loaded_after_heavenly = False
        self.pre_heaven_save_started = False
        self.pre_heaven_save_done = False
        self.pre_heaven_load_started = False
        self.pre_heaven_load_done = False
        self.lines: List[str] = []

    def log(self, line: str) -> None:
        msg = f"[{now()}] {line}"
        self.lines.append(msg)
        try:
            self.report_path.parent.mkdir(parents=True, exist_ok=True)
            self.report_path.write_text("\n".join(self.lines) + "\n", encoding="utf-8")
        except OSError:
            pass
        try:
            print(msg, flush=True)
        except UnicodeEncodeError:
            safe = msg.encode("utf-8", errors="replace").decode("utf-8", errors="replace")
            print(safe, flush=True)

    def start(self) -> None:
        if not self.exe.exists():
            raise FileNotFoundError(f"exe not found: {self.exe}")
        for path in [self.state_path, self.command_path, self.trace_path, self.report_path]:
            try:
                if path.exists():
                    path.unlink()
            except OSError:
                pass

        env = os.environ.copy()
        env["WENDAO_AGENT_STATE"] = str(self.state_path)
        env["WENDAO_AGENT_COMMAND"] = str(self.command_path)
        env["WENDAO_AGENT_HIDE"] = "1"
        env["WENDAO_TRACE_LOG"] = str(self.trace_path)
        env["WENDAO_TRACE_HIDE"] = "1"
        env["PYTHONUTF8"] = "1"
        # 明确关闭旧的全自动 trace，避免与 agent 驱动抢按键。
        env.pop("WENDAO_TRACE_AUTOPLAY", None)
        env.pop("WENDAO_DAOZU_SMOKE", None)

        self.log("启动游戏并启用 Agent Bridge。")
        self.proc = subprocess.Popen([str(self.exe)], cwd=str(self.release_dir), env=env)

    def stop(self) -> None:
        try:
            self.send("QUIT", wait_after=False)
        except Exception:
            pass
        time.sleep(0.5)
        if self.proc and self.proc.poll() is None:
            self.log("进程未主动退出，执行 terminate。")
            self.proc.terminate()
            try:
                self.proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.proc.kill()

    def read_state(self) -> Optional[Dict[str, Any]]:
        if not self.state_path.exists():
            return None
        for _ in range(3):
            try:
                raw = self.state_path.read_text(encoding="utf-8-sig")
                if not raw.strip():
                    return None
                return json.loads(raw)
            except (OSError, json.JSONDecodeError):
                time.sleep(0.05)
        return None

    def wait_state(self, timeout: float = 10.0) -> Dict[str, Any]:
        end = time.time() + timeout
        last_error = "state not ready"
        while time.time() < end:
            if self.proc and self.proc.poll() is not None:
                raise RuntimeError(f"game exited early with code {self.proc.returncode}")
            state = self.read_state()
            if state:
                return state
            time.sleep(POLL_SECONDS)
        raise TimeoutError(last_error)

    def send(self, command: str, wait_after: bool = True) -> None:
        self.command_seq += 1
        line = f"{self.command_seq:05d} {command}\n"
        self.command_path.write_text(line, encoding="utf-8")
        self.log(f"ACTION {line.strip()}")
        if wait_after:
            time.sleep(POLL_SECONDS * 2)

    def choose_event_key(self, state: Dict[str, Any]) -> str:
        event = state.get("event") or {}
        choices = event.get("choices") or []
        if not choices:
            return "1"
        positive = ["稳", "守", "问", "查", "听", "观", "护", "谢", "应", "补", "救", "避", "缓", "静", "明", "共", "证", "悟", "辨", "认"]
        risky = ["赌", "抢", "夺", "硬", "闯", "签", "强", "逼", "压", "杀", "怒", "冒进"]
        player = state.get("player") or {}
        hp = int(player.get("hp") or 0)
        max_hp = max(1, int(player.get("maxHp") or 1))
        realm_index = int(player.get("realmIndex") or 0)

        best_score = -10_000
        best_index = 1
        for choice in choices:
            idx = int(choice.get("index") or 1)
            text = str(choice.get("text") or "")
            score = 0
            score += sum(2 for key in positive if key in text)
            score -= sum(3 for key in risky if key in text)
            if hp < max_hp * 0.4 and any(key in text for key in ["护", "避", "稳", "退", "缓"]):
                score += 4
            if realm_index >= DAO_ANCESTOR_INDEX and any(key in text for key in ["道", "鸿蒙", "权柄", "天道", "掌", "证", "悟"]):
                score += 5
            if score > best_score:
                best_score = score
                best_index = idx
        return str(best_index)

    def game_action(self, state: Dict[str, Any], step: int) -> str:
        player = state.get("player") or {}
        realm_index = int(player.get("realmIndex") or 0)
        level = int(player.get("level") or 1)
        exp = int(player.get("exp") or 0)
        need_exp = max(1, int(player.get("needExp") or 1))
        hp = int(player.get("hp") or 0)
        max_hp = max(1, int(player.get("maxHp") or 1))
        stones = int(player.get("spiritStones") or 0)
        pills = int(player.get("pills") or 0)
        can_break = bool(state.get("canBreakthrough"))
        heavenly_ready = bool(state.get("heavenlyDaoReady"))
        closed_door_cost = 10 + realm_index * 2
        can_closed_door = stones >= closed_door_cost + 10

        if realm_index >= HEAVENLY_DAO_INDEX:
            return "QUIT"

        # 天道突破会直接进入结局/轮回页；因此在最后突破前先做一次存档和读档验收。
        if realm_index >= DAO_ANCESTOR_INDEX and heavenly_ready and can_break:
            if not self.pre_heaven_save_done:
                self.pre_heaven_save_started = True
                return "KEY S"
            if self.pre_heaven_save_done and not self.pre_heaven_load_done:
                self.pre_heaven_load_started = True
                return "KEY L"
            return "KEY 3"

        if can_break:
            return "KEY 3"
        if hp < max_hp * 0.35 and pills > 0:
            return "KEY 4"

        # 道祖门槛解锁后，仍需要把道祖修到九层并蓄满修为；上一轮在道祖一层反复按突破卡住。
        if realm_index >= DAO_ANCESTOR_INDEX:
            if not heavenly_ready:
                return "KEY 2"
            if can_closed_door and (level < 9 or exp < need_exp) and step % 4 != 1:
                return "KEY 5"
            if level >= 8 and step % 5 == 0:
                return "KEY 2"
            return "KEY 1"

        # 上一轮 720 秒只到玄仙八层，主要慢在高层长期历练；这里把灵石闭关提前，
        # 保留每三步一次历练用于触发剧情条件，其余尽量走闭关/修炼加速推进。
        if can_closed_door and step % 3 != 1 and (level < 9 or exp < need_exp):
            return "KEY 5"

        # 大乘九层满修为但五行不均时，游戏自身会把历练导向五行补缺事件。
        if level >= 9 and exp >= need_exp:
            return "KEY 2"

        # 高层仍保留一定历练比例，避免完全闭关导致主线条件不足。
        if level >= 8 and step % 4 == 0:
            return "KEY 2"

        if step % 4 == 1:
            return "KEY 2"
        return "KEY 1"

    def note_state(self, state: Dict[str, Any], step: int) -> None:
        player = state.get("player") or {}
        realm_index = int(player.get("realmIndex") or 0)
        realm = player.get("realm", "?")
        level = player.get("level", "?")
        exp = player.get("exp", "?")
        need_exp = player.get("needExp", "?")
        hp = player.get("hp", "?")
        max_hp = player.get("maxHp", "?")
        generation = state.get("generation", "?")
        feedback = str(state.get("feedback") or "").replace("\n", " / ")
        fingerprint = f"{generation}|{realm_index}|{level}|{exp}|{hp}|{feedback[:80]}"

        if realm_index != self.last_realm_index:
            self.log(f"REALM step={step} generation={generation} -> {realm} {level}层 exp={exp}/{need_exp} hp={hp}/{max_hp}")
            self.last_realm_index = realm_index
            self.last_realm_step = step

        if fingerprint == self.last_player_fingerprint:
            self.same_fingerprint_ticks += 1
        else:
            self.same_fingerprint_ticks = 0
            self.last_player_fingerprint = fingerprint

    def run(self) -> int:
        self.start()
        start_time = time.time()
        try:
            state = self.wait_state(20)
            self.log(f"初始状态：{state.get('state')}")

            for step in range(1, MAX_STEPS + 1):
                if time.time() - start_time > MAX_SECONDS:
                    self.log(f"FAIL 超时：{MAX_SECONDS}s 内未完成。")
                    return 2
                if self.proc and self.proc.poll() is not None:
                    self.log(f"FAIL 游戏进程提前退出，code={self.proc.returncode}")
                    return 3

                state = self.wait_state(5)
                self.note_state(state, step)
                game_state = state.get("state")
                player = state.get("player") or {}
                realm_index = int(player.get("realmIndex") or 0)

                if realm_index >= HEAVENLY_DAO_INDEX:
                    self.heavenly_reached = True

                if game_state == "MENU":
                    self.send("START 玄微真人式测试")
                elif game_state == "GAME":
                    cmd = self.game_action(state, step)
                    if cmd == "QUIT":
                        self.log("已抵达道祖-天道境，Agent Bridge 验收完成。")
                        self.send("QUIT")
                        return 0
                    self.send(cmd)
                elif game_state == "EVENT":
                    key = self.choose_event_key(state)
                    event = state.get("event") or {}
                    self.log(f"EVENT {event.get('title', '')} -> 选择 {key}")
                    self.send(f"KEY {key}")
                elif game_state == "INFO":
                    if self.pre_heaven_save_started and not self.pre_heaven_save_done:
                        self.pre_heaven_save_done = True
                        self.log("天道突破前存档页已出现，选择 1 号槽位保存。")
                        self.send("KEY 1")
                    elif self.pre_heaven_load_started and not self.pre_heaven_load_done:
                        self.pre_heaven_load_done = True
                        self.log("天道突破前读档页已出现，选择 1 号槽位读取。")
                        self.send("KEY 1")
                    elif self.heavenly_reached:
                        self.log("已抵达道祖-天道境，当前处于结局信息页，验收完成。")
                        self.send("QUIT")
                        return 0
                    else:
                        self.send("KEY ESC")
                elif game_state == "GAMEOVER":
                    if self.heavenly_reached:
                        self.log("已抵达道祖-天道境并进入结局/轮回页，Agent Bridge 验收完成。")
                        self.send("QUIT")
                        return 0
                    generation = int(state.get("generation") or 1)
                    if generation >= 8:
                        self.log("FAIL 多世轮回后仍未抵达天道境。")
                        return 4
                    self.log("GAMEOVER，进入下一世继续人工式推进。")
                    self.send("KEY N")
                elif game_state == "AI_WAIT":
                    self.log("AI_WAIT 停留，按 ESC 让本轮回退到规则事件。")
                    self.send("KEY ESC")
                else:
                    self.log(f"未知状态 {game_state}，发送 WAIT。")
                    self.send("WAIT")

                if self.same_fingerprint_ticks >= 80:
                    self.log("FAIL 状态长时间没有明显变化，疑似卡住。")
                    return 5

            self.log(f"FAIL 达到最大步数 {MAX_STEPS} 仍未完成。")
            return 6
        finally:
            self.stop()
            self.log(f"trace={self.trace_path}")
            self.log(f"state={self.state_path}")
            self.log(f"command={self.command_path}")


def main() -> int:
    if len(sys.argv) >= 2:
        release_dir = Path(sys.argv[1])
    else:
        release_dir = Path.cwd() / "release"
    driver = AgentDriver(release_dir)
    return driver.run()


if __name__ == "__main__":
    raise SystemExit(main())
