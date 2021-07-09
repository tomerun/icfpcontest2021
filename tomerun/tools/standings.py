import html
import json
import re
from urllib import request
from datetime import datetime, timedelta

standings_url = "https://poses.live/teams"
slack_url = "https://hooks.slack.com/services/xxxxxxxxxxx/xxxxxxxxxxx/xxxxxxxxxxxxxxxxxxxxxxxx"


def lambda_handler(event, context):
    req = request.Request(standings_url)
    with request.urlopen(req) as res:
        now = datetime.now() + timedelta(hours=9)
        now = now.replace(microsecond=0)
        body = html.unescape(res.read().decode())
        teams = []
        for m in re.finditer(r"<tr><td>(\d+)</td><td>(.*?)</td><td>(\d+)</td></tr>", body):
            teams.append((m[1], m[2], m[3]))
    print(teams)
    teams = teams[:30]
    len_place = max(len(t[0]) for t in teams)
    len_name = max(len(t[1]) for t in teams)
    len_score = max(len(t[2]) for t in teams)
    fmt = f"%{len_place}s %{len_name}s %{len_score}s"
    standings = "\n".join(fmt % t for t in teams)
    # print(standings)
    standings = html.escape(standings)
    message = json.dumps({
        "blocks": [
            {
                "type": "header",
                "text": {
                    "type": "plain_text",
                    "text": f"standings at {now}"
                }
            },
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": f"```{standings}```"
                }
            },
        ]
    }).encode()
    headers = {"Content-Type": "application/json"}
    req = request.Request(slack_url, data=message, headers=headers)
    with request.urlopen(req) as res:
        print(res.read().decode())


if __name__ == '__main__':
    lambda_handler(None, None)