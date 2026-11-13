# Configure pipeline notifications in Microsoft Teams 📣

- [Configure pipeline notifications in Microsoft Teams 📣](#configure-pipeline-notifications-in-microsoft-teams-)
  - [Overview 🧭](#overview-)
    - [How it is implemented](#how-it-is-implemented)
  - [Before you start 📋](#before-you-start-)
  - [Create the Power Automate flow 🔧](#create-the-power-automate-flow-)
    - [Create the trigger](#create-the-trigger)
    - [Add the channel action](#add-the-channel-action)
  - [Test the webhook 🧪](#test-the-webhook-)
  - [Configure the GitHub secret 🔐](#configure-the-github-secret-)
  - [Verify pipeline delivery ✅](#verify-pipeline-delivery-)
  - [Maintain the integration 🔄](#maintain-the-integration-)
  - [Troubleshooting 🔍](#troubleshooting-)

## Overview 🧭

The CI/CD workflows send status notifications to a Microsoft Teams channel.
They help the team spot a broken trunk and see when a release is published or
deployed. This guide is for engineers who configure the repository and the
channel connection.

The template's notification jobs report these events:

- Pushes to `main` report failures and recovery after a broken streak. A failure
  asks the team to stop merging. A routine passing run does not send a message.
  Pull request runs do not send these trunk notifications.
- The publish workflow reports failures and successful publication after a pull
  request is merged.
- The deploy workflow reports failures and successful deployments.

A cancelled workflow does not notify. A job that fails or is cancelled within a
run that continues can produce a failure notification. For trunk notifications,
the script checks recent completed runs of the same workflow, branch and event.
It suppresses an older run's notification when a newer success or failure has
already completed, and skips cancelled runs when finding a broken streak.

### How it is implemented

Each pipeline calls the reusable
[notification workflow](../../../.github/workflows/notify-pipeline-status.yaml)
after its other jobs. The
[status script](../../../scripts/cicd/notify-pipeline-status.sh) reads their
results, looks up failed jobs and commit details through the GitHub CLI, and
decides whether to report failure, recovery, success or nothing. The
[jq renderer](../../../scripts/cicd/notify-pipeline-status.jq) builds the message
and removes Markdown and invisible characters from untrusted values. The script
writes the message to the GitHub Actions step summary.

The workflow uses the pinned
[notify-msteams-action](https://github.com/nhs-england-tools/notify-msteams-action)
to send an Adaptive Card to a Power Automate webhook. The flow forwards the card
to the chosen Teams channel. GitHub API access uses the workflow's `GITHUB_TOKEN`
with `actions: read` and `contents: read`. No personal access token is needed.

Without the `TEAMS_NOTIFICATION_WEBHOOK_URL` secret, a reportable run writes its
summary and warns that the team was not notified. A failed Teams delivery step
does not change the pipeline result. A green pipeline is therefore not proof
that a notification arrived.

## Before you start 📋

You need:

- Access to Power Automate in the **NHSE Dev** environment, with permission to
  create a cloud flow and use the Microsoft Teams connector.
- A Teams account that can post to the destination team and channel. Use a
  standard channel for this setup. The Teams connector documents limitations
  for private channels.
- Permission to create a GitHub Actions repository secret, or help from a
  repository administrator.
- Bash and `curl` for the optional direct webhook test.

Agree which channel should receive pipeline messages and who will maintain the
flow. Select your own team if the repository belongs elsewhere. Ask the platform
administrators for help if the environment, connector or destination is
unavailable.

> [!IMPORTANT]
>
> This integration uses **Anyone** as the webhook trigger's authentication
> setting. Anyone who obtains the full URL can invoke the flow. Treat it as a
> credential, including its query string. Do not put it in source control,
> documentation, tickets, screenshots or shared terminal output. Check that this
> configuration is permitted by your organisation's policies before proceeding.

## Create the Power Automate flow 🔧

### Create the trigger

1. Open the
   [NHSE Dev flows page](https://make.powerautomate.com/environments/b87b7c74-9fc2-eed1-af99-2e00ea35aead/flows)
   and sign in with your NHS account. Confirm that the environment selector
   shows **NHSE Dev**.
2. Select **My flows > + New flow > Instant cloud flow**.
3. Give the flow a name that identifies the repository and destination, such as
   `repository-template pipeline notifications`.
4. Under **Choose how to trigger this flow**, select **When a Teams webhook
   request is received**, then select **Create**. Do not choose a generic HTTP
   trigger or a legacy Incoming Webhook connector.
5. If the **New designer** toggle is available, turn it off to follow the
   original setup. Labels and dynamic content controls can differ in the new
   designer, but the trigger and card mapping below are the same.
6. Open the trigger and set **Who can trigger the flow?** to **Anyone**. The
   GitHub action sends a JSON POST without a Microsoft Entra bearer token.
   Tenant-only authentication would require a different sender configuration.

### Add the channel action

1. Select **+ New step** and choose the Microsoft Teams action **Post card in a
   chat or channel**. Do not choose the action that waits for a response.
2. Sign in to the Teams connection if prompted.
3. Set **Post as** to **Flow bot** and **Post in** to **Channel**.
4. Set **Team** to **[Your Team]** then select the destination **Channel**.
5. In **Adaptive Card**, open dynamic content using the lightning bolt icon or
   **Add dynamic content**. Select **Adaptive Card** from the webhook trigger.
   If Power Automate creates an **Apply to each** loop for the attachments,
   keep the posting action inside it.

The incoming request contains an `attachments` array. The posting action needs
the card object inside each attachment's `content`, not the complete request
body or the attachment wrapper. If the dynamic content field is unavailable,
enter this expression in the **Expression** editor of **Adaptive Card** for this
single-card integration:

```text
triggerBody()?['attachments']?[0]?['content']
```

Use either the dynamic content loop or the single-card expression, not two
posting actions. Do not type the words `Adaptive Card` as literal text, and do
not paste a fixed test card into the field. The flow must forward the card sent
by GitHub.

Select **Save**, resolve any connection or validation errors, then reopen
**When a Teams webhook request is received**. Copy its **HTTP POST URL**. The
URL is generated after saving. Confirm that the flow is turned on.

## Test the webhook 🧪

Tell the channel that you are sending a test message. In a local **Bash**
terminal with command tracing disabled, run the following. Paste the webhook URL
at the hidden prompt. This keeps the literal URL out of your shell history.

```bash
read -r -s -p 'Teams webhook URL: ' teams_webhook_url
printf '\n'
curl --fail --silent --show-error \
  --output /dev/null --write-out 'HTTP %{http_code}\n' \
  --request POST "$teams_webhook_url" \
  --header 'Content-Type: application/json' \
  --data-binary '{
    "type": "message",
    "attachments": [
      {
        "contentType": "application/vnd.microsoft.card.adaptive",
        "contentUrl": null,
        "content": {
          "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
          "type": "AdaptiveCard",
          "version": "1.4",
          "body": [
            {
              "type": "TextBlock",
              "text": "Power Automate webhook test",
              "wrap": true
            }
          ]
        }
      }
    ]
  }'
unset teams_webhook_url
```

Expect an HTTP `2xx` response, commonly `202`, and a card saying **Power Automate
webhook test** in the selected channel. In Power Automate, open the flow's
**Run history** and confirm that both the trigger and posting action succeeded.
An accepted request does not guarantee that the later Teams action succeeded.
Do not add an `Authorization` header when the trigger is set to **Anyone**.

The outer `message` and `attachments` fields form the webhook envelope. The
inner `content` is the Adaptive Card. See the
[Adaptive Card samples](https://adaptivecards.io/samples/) for other card layouts.
You do not need to customise a card to enable the repository notifications.

## Configure the GitHub secret 🔐

1. Open the repository on GitHub and go to **Settings > Secrets and variables >
   Actions**.
2. Under **Repository secrets**, select **New repository secret**.
3. Enter `TEAMS_NOTIFICATION_WEBHOOK_URL` as the name.
4. Paste the complete **HTTP POST URL** from the saved trigger as the value,
   without quotes or extra whitespace. Select **Add secret**.

An organisation-level Actions secret is also suitable if its repository access
policy includes this repository. Use a secret, not an Actions variable or a
Codespaces secret. The existing callers already pass this secret to the reusable
workflow. No workflow edit is needed to enable delivery. Fork pull requests do
not receive repository secrets, and the trunk notification job does not run on
pull request events.

## Verify pipeline delivery ✅

Use the next expected notification from a normal pipeline run. A routine passing
push to `main` is intentionally silent. A successful publish or deploy run is
suitable when that operation is already planned. Do not publish, deploy or break
`main` just to test notifications. Use the direct webhook test first.

In GitHub Actions, open the run and its notification job. Check the pipeline
message in the step summary, then confirm that the **Notify Microsoft Teams**
step ran rather than being skipped. Check Power Automate **Run history** and
confirm that the corresponding card reached the intended channel. Follow the
card's link to confirm that it points to the expected run or release.

## Maintain the integration 🔄

Add another appropriate maintainer as a co-owner through the flow's sharing
settings. Record its name, environment, destination channel and owners in your
team's operational records, without recording the webhook URL there. Check the
Teams connection when an owner leaves or their account changes. Co-ownership
alone does not replace the account used by that connection.

To move notifications, edit the flow's team and channel, save it and repeat the
webhook test. If the trigger URL changes, update the GitHub secret too.

If the URL is exposed, turn off the compromised flow promptly. Arrange a
replacement webhook with the flow owner, update the GitHub secret, test delivery
and retire the old endpoint. Merely changing the GitHub secret does not revoke
the old URL.

To disable delivery for one repository, remove its access to the Actions secret.
Reportable runs will still write a summary and warn. Turn off or delete the flow
only when no other repository relies on it.

## Troubleshooting 🔍

- **The trigger or Teams action is unavailable:** check **NHSE Dev** is selected
  and ask the platform administrators about permissions and connector policies.
  The Teams Workflows app must be allowed by the tenant administrator.
- **The test returns `401` or `403`:** confirm the trigger permits **Anyone**,
  no bearer token is sent and the complete current URL was copied after saving.
  Check tenant policy with the administrators if it still fails.
- **The request is accepted but no card appears:** inspect the flow's run
  history. Check the Teams connection, destination, posting action and card
  mapping. Forward the attachment's `content`, not the whole request body.
- **The pipeline says “Team not notified”:** check the exact Actions secret name
  and its repository access policy. This is expected when it has not been set.
- **The delivery step is skipped:** check whether a notification was needed.
  Routine trunk success, cancelled workflows and older superseded trunk runs do
  not notify. Publish and deploy have their own calling-job conditions.
- **The pipeline passes but delivery fails:** open the delivery step's logs and
  the flow's run history. The delivery step deliberately continues on error.
  Check the webhook, connection and GitHub API error before retrying. Redact
  credentials before sharing diagnostics.
- **A recovery or job detail is missing:** inspect warning annotations from the
  status script. Failed GitHub lookups can reduce the message detail. Also check
  the pinned action limitations described above.

For trigger authentication, request schemas and connector limitations, see the
[Microsoft Teams connector reference](https://learn.microsoft.com/en-us/connectors/teams/#when-a-teams-webhook-request-is-received).
