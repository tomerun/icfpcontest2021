import boto3
import html
import json
import re
from urllib import request
from datetime import datetime, timedelta

standings_url = "https://poses.live/teams"
slack_url = "https://hooks.slack.com/services/xxxxxxxxxxx/xxxxxxxxxxx/xxxxxxxxxxxxxxxxxxxxxxxx"


def lambda_handler(event, context):
    s3 = boto3.client("s3")
    prev = None
    try:
        res = s3.get_object(Bucket="icfpc-2021", Key="standings/latest.json")
        prev_teams = json.loads(res["Body"].read().decode())
        prev = {t[1]: (t[0], t[2]) for t in prev_teams}
    except Exception as e:
        print(e)
        pass
    req = request.Request(standings_url)
    with request.urlopen(req) as res:
        now = datetime.now() + timedelta(hours=9)
        now = now.replace(microsecond=0)
        body = html.unescape(res.read().decode())
        teams_all = []
        for m in re.finditer(r"<tr><td>(\d+)</td><td>(.*?)</td><td>(\d+)</td></tr>", body):
            teams_all.append([m[1], m[2], m[3]])
    # print(teams_all)
    s3.put_object(
        Bucket="icfpc-2021",
        Key=f"standings/{now.strftime('%Y%m%d_%H%M%S')}.json",
        Body=json.dumps(teams_all).encode())
    s3.put_object(
        Bucket="icfpc-2021", Key="standings/latest.json", Body=json.dumps(teams_all).encode())

    teams = []
    for i, t in enumerate(teams_all):
        if i < 25 or t[1] == "Independent Set":
            teams.append(t)
    if prev:
        for t in teams:
            if t[1] not in prev:
                continue
            prev_rank, prev_score = prev[t[1]]
            diff = int(t[0]) - int(prev_rank)
            if diff > 0:
                diff = f"▼{diff}"
            elif diff < 0:
                diff = f"△{abs(diff)}"
            else:
                diff = "0"
            t[0] = f"{t[0]}({diff})"

            diff = int(t[2]) - int(prev_score)
            if diff > 0:
                diff = f"+{diff}"
            else:
                diff = str(diff)
            t.append(f"({diff})")

    len_place = max(len(t[0]) for t in teams) + 1
    len_name = max(len(t[1]) for t in teams)
    len_score = max(len(t[2]) for t in teams)
    fmt = f"%{len_place}s  %{len_name}s  %{len_score}s%s"
    standings = "\n".join(fmt % tuple(t) for t in teams)
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