const fs = require("fs");

const marker = "<!-- dart-simple-live-discussion-poll-chart -->";
const owner = process.env.REPO_OWNER;
const repo = process.env.REPO_NAME;
const discussionNumber = Number(process.env.DISCUSSION_NUMBER || "68");
const token = process.env.GITHUB_TOKEN;
const outputPath = process.env.OUTPUT_PATH || "poll-comment.md";
const dryRun = process.env.DRY_RUN === "true";

if (!owner || !repo || !discussionNumber || !token) {
  throw new Error("Missing REPO_OWNER, REPO_NAME, DISCUSSION_NUMBER, or GITHUB_TOKEN.");
}

async function graphql(query, variables) {
  const response = await fetch("https://api.github.com/graphql", {
    method: "POST",
    headers: {
      "authorization": `Bearer ${token}`,
      "content-type": "application/json",
      "user-agent": "dart-simple-live-poll-chart",
    },
    body: JSON.stringify({ query, variables }),
  });

  const payload = await response.json();
  if (!response.ok || payload.errors) {
    throw new Error(JSON.stringify(payload.errors || payload, null, 2));
  }
  return payload.data;
}

function percent(count, total) {
  if (total === 0) return "0.0";
  return ((count / total) * 100).toFixed(1);
}

function buildContent(discussion) {
  const poll = discussion.poll;
  if (!poll) {
    throw new Error(`Discussion #${discussionNumber} does not have a poll.`);
  }

  const total = poll.totalVoteCount;
  const rows = poll.options.nodes
    .map((item) => {
      const rate = percent(item.totalVoteCount, total);
      return `| ${item.option} | ${item.totalVoteCount} | ${rate}% |`;
    })
    .join("\n");

  return `${marker}
## 投票实时统计

**${poll.question}**

| 选项 | 票数 | 占比 |
|---|---:|---:|
${rows}
| **合计** | **${total}** | **100%** |`;
}

function buildBody(discussion) {
  const content = buildContent(discussion);
  const updatedAt = new Date().toISOString().replace("T", " ").replace(/\.\d{3}Z$/, " UTC");

  return `${content}

更新时间：${updatedAt}

> 此评论由 GitHub Actions 自动更新。`;
}

function hasCurrentPollContent(commentBody, content) {
  return typeof commentBody === "string" && commentBody.includes(content);
}

function isPermissionError(error) {
  const message = error instanceof Error ? error.message : String(error);
  return message.includes("FORBIDDEN") || message.includes("Resource not accessible by integration");
}

function pickManagedComments(comments) {
  return comments
    .filter((comment) => comment.body.includes(marker))
    .sort((left, right) => new Date(left.createdAt).getTime() - new Date(right.createdAt).getTime());
}

async function removeDuplicateComments(comments, keepId) {
  for (const comment of comments) {
    if (comment.id === keepId) {
      continue;
    }

    if (!comment.viewerCanDelete) {
      console.warn(`Managed comment ${comment.id} is not deletable by the current token; left it untouched.`);
      continue;
    }

    await graphql(deleteMutation, { commentId: comment.id });
    console.log(`Deleted duplicate poll chart comment: ${comment.id}`);
  }
}

async function createManagedComment(discussionId, body) {
  const result = await graphql(addMutation, { discussionId, body });
  console.log(`Created poll chart comment: ${result.addDiscussionComment.comment.id}`);
  return result.addDiscussionComment.comment.id;
}

async function refreshManagedComments(discussionId, body, comments, reason) {
  const blocked = comments.filter((comment) => !comment.viewerCanDelete);

  for (const comment of comments) {
    if (!comment.viewerCanDelete) {
      console.warn(`${reason} Current token also cannot delete managed comment ${comment.id}; creating a new current comment instead.`);
      continue;
    }

    await graphql(deleteMutation, { commentId: comment.id });
    console.log(`Deleted stale poll chart comment: ${comment.id}`);
  }

  if (blocked.length) {
    console.warn("Configure DISCUSSION_BOT_TOKEN with permission to edit or delete old bot comments if you want duplicate cleanup.");
  }

  return createManagedComment(discussionId, body);
}

const query = `
query($owner:String!, $repo:String!, $number:Int!) {
  repository(owner:$owner, name:$repo) {
    discussion(number:$number) {
      id
      title
      poll {
        question
        totalVoteCount
        options(first: 50) {
          nodes {
            option
            totalVoteCount
          }
        }
      }
      comments(last: 100) {
        nodes {
          id
          body
          createdAt
          viewerCanUpdate
          viewerCanDelete
        }
      }
    }
  }
}`;

const addMutation = `
mutation($discussionId:ID!, $body:String!) {
  addDiscussionComment(input:{discussionId:$discussionId, body:$body}) {
    comment { id }
  }
}`;

const updateMutation = `
mutation($commentId:ID!, $body:String!) {
  updateDiscussionComment(input:{commentId:$commentId, body:$body}) {
    comment { id }
  }
}`;

const deleteMutation = `
mutation($commentId:ID!) {
  deleteDiscussionComment(input:{id:$commentId}) {
    clientMutationId
  }
}`;

(async () => {
  const data = await graphql(query, { owner, repo, number: discussionNumber });
  const discussion = data.repository.discussion;
  if (!discussion) {
    throw new Error(`Discussion #${discussionNumber} was not found.`);
  }

  const content = buildContent(discussion);
  const body = buildBody(discussion);
  fs.writeFileSync(outputPath, `${body}\n`, "utf8");

  if (dryRun) {
    console.log(body);
    console.log("Dry run enabled; skipped creating or updating the discussion comment.");
    return;
  }

  const managedComments = pickManagedComments(discussion.comments.nodes);
  const current = managedComments.find((comment) => hasCurrentPollContent(comment.body, content));
  const editable = managedComments.find((comment) => comment.viewerCanUpdate);

  if (!managedComments.length) {
    await createManagedComment(discussion.id, body);
    return;
  }

  if (current) {
    console.log(`Managed comment ${current.id} already has the latest poll data; skipped timestamp-only refresh.`);
    return;
  }

  if (!editable) {
    await refreshManagedComments(
      discussion.id,
      body,
      managedComments,
      "Found an existing stale poll chart comment, but the current token cannot update it.",
    );
    return;
  }

  try {
    await graphql(updateMutation, { commentId: editable.id, body });
    console.log(`Updated poll chart comment: ${editable.id}`);
  } catch (error) {
    if (!isPermissionError(error)) {
      throw error;
    }
    if (hasCurrentPollContent(editable.body, content)) {
      console.log(`Managed comment ${editable.id} already has the latest poll data; skipped after update permission failure.`);
      return;
    }
    await refreshManagedComments(
      discussion.id,
      body,
      managedComments,
      `Unable to update managed comment ${editable.id}.`,
    );
    return;
  }

  await removeDuplicateComments(managedComments, editable.id);
})();
