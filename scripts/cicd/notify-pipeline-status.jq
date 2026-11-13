# Render the Microsoft Teams message for a pipeline status, run by
# ./scripts/cicd/notify-pipeline-status.sh with 'jq -n' and these variables:
#   $status         'failure', 'recovered' or 'success'
#   $stop_the_line  true when the run guards the trunk
#   $repository, $server_url, $run_id  the GitHub Actions run
#   $workflow, $event, $actor, $attempt  shown as facts
#   $failed_jobs    [{name, url}], url is null when not known
#   $commit         {sha, url, subject}, url is null when not known
#   $broken_since   {number, url, minutes}, the first broken run of the streak
#   $details        'Label: value' lines, one per line
#   $success_title, $success_text, $success_link  the message of a success
# Output: {title, colour, text, facts, link, link_title, summary}. The text is
# Markdown with a blank line between paragraphs, the facts are 'Label: value'
# lines and the summary is the Markdown of the step summary.

# Text the pipeline does not control, made safe to place in Markdown: no
# control or invisible format characters, no Markdown or HTML special
# characters, single spaces, trimmed and at most $max characters.
def clean($max):
  tostring
  | gsub("[\\t\\n\\r]"; " ")
  | gsub("[\\p{Cc}\\p{Cf}\\p{Co}\\p{Cs}\\p{Zl}\\p{Zp}]"; "")
  | gsub("\\p{Zs}"; " ")
  | gsub("[\\[\\]<>&\"'`*_\\\\]"; "")
  | gsub(" {2,}"; " ")
  | sub("^ "; "")
  | sub(" $"; "")
  | .[0:$max];

def clean: clean(100);

def https_url: type == "string" and test("^https://[^\\s()<>]+$");

# A Markdown link, or the text alone when the URL is not a plain https URL.
def link($text; $url):
  if $url | https_url then
    "[\($text)](\($url))"
  else
    $text
  end;

def plural($unit): "\(.) \($unit)\(if . == 1 then "" else "s" end)";

# A number of minutes in words, such as '1 hour 5 minutes'.
def duration:
  if . < 1 then
    "less than a minute"
  elif . < 60 then
    plural("minute")
  else
    (. / 60 | floor | plural("hour"))
    + (. % 60 | if . > 0 then " " + plural("minute") else "" end)
  end;

def commit_line:
  link(.sha[0:7] | clean; .url)
  + (.subject | clean | if . != "" then " " + . else "" end);

($server_url | sub("/+$"; "")) as $server_url
| ($server_url + "/" + $repository) as $repository_url
| ($repository_url + "/actions/runs/" + ($run_id | @uri)) as $run_url
| ($status == "success" and ($success_link | https_url)) as $success_linked
| (
    [
      "Workflow: \($workflow | clean)",
      "Triggered by: \($actor | sub("\\[bot\\]$"; " (bot)") | clean) via \($event | gsub("[^a-z_]"; ""))"
    ]
    + ($attempt | clean | if . != "1" then ["Attempt: " + .] else [] end)
    + [
      $details | split("\n")[]
      | capture("^(?<label>[^:]+):(?<value>.*)$")
      | {label: (.label | clean), value: (.value | clean)}
      | select(.label != "" and .value != "")
      | "\(.label): \(.value)"
    ]
  ) as $facts
| {
    title: (
      if $status == "success" then "🟢 \($success_title | clean)"
      elif $status == "recovered" then "🟢 RECOVERED"
      elif $stop_the_line then "🔴 PIPELINE BROKEN"
      else "🔴 FAILED"
      end
    ),
    colour: (if $status == "failure" then "attention" else "good" end),
    text: (
      if $status == "success" then
        ($success_text | clean(300) | if . != "" then [.] else [] end)
        + ["**Commit:** \($commit | commit_line)"]
      elif $status == "recovered" then
        [
          "**Pipeline is green again.** Merging can resume.",
          "**Broken for:** \($broken_since.minutes | duration), since \(link("run \($broken_since.number)"; $broken_since.url // ($repository_url + "/actions/runs/\($broken_since.number)")))",
          "**Fixed by:** \($commit | commit_line)"
        ]
      else
        [
          if $stop_the_line then
            "**Pipeline broken.** Stop merging until it is green again. Fix forward or revert within 10 minutes."
          else
            "**Pipeline failed.**"
          end,
          "**Failed jobs:**",
          ($failed_jobs | map("- " + link(.name | clean; .url // $run_url)) | join("\n")),
          "**Commit:** \($commit | commit_line)"
        ]
      end
      | join("\n\n")
    ),
    facts: ($facts | join("\n")),
    link: (if $success_linked then $success_link else $run_url end),
    link_title: (if $success_linked then "View" else "View the run" end)
  }
| .summary = (
    [
      "### \(.title)",
      .text,
      ($facts | map(capture("^(?<label>[^:]+): (?<value>.*)$") | "- **\(.label):** \(.value)") | join("\n")),
      "[\(.link_title)](\(.link))"
    ]
    | join("\n\n")
  )
