import ReactMarkdown from 'react-markdown';

type MarkdownMessageProps = {
  text: string;
};

export function MarkdownMessage({ text }: MarkdownMessageProps) {
  return (
    <div className="message-markdown">
      <ReactMarkdown
        components={{
          p: ({ node: _node, ...props }) => <p {...props} />,
          ul: ({ node: _node, ...props }) => <ul {...props} />,
          ol: ({ node: _node, ...props }) => <ol {...props} />,
          li: ({ node: _node, ...props }) => <li {...props} />,
          strong: ({ node: _node, ...props }) => <strong {...props} />,
          em: ({ node: _node, ...props }) => <em {...props} />,
          code: ({ node: _node, ...props }) => <code {...props} />,
          a: ({ node: _node, ...props }) => <a {...props} target="_blank" rel="noreferrer" />,
        }}
      >
        {text}
      </ReactMarkdown>
    </div>
  );
}
