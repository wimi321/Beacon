import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { MarkdownMessage } from './MarkdownMessage';

describe('MarkdownMessage', () => {
  it('renders plain text correctly', () => {
    render(<MarkdownMessage text="Hello world" />);

    expect(screen.getByText('Hello world')).toBeInTheDocument();
  });

  it('renders bold markdown (**text**)', () => {
    const { container } = render(<MarkdownMessage text="This is **bold** text" />);

    const strong = container.querySelector('strong');
    expect(strong).not.toBeNull();
    expect(strong!.textContent).toBe('bold');
  });

  it('links have target="_blank" and rel="noreferrer"', () => {
    render(<MarkdownMessage text="Visit [Example](https://example.com) now" />);

    const link = screen.getByRole('link', { name: 'Example' });
    expect(link).toHaveAttribute('target', '_blank');
    expect(link).toHaveAttribute('rel', 'noreferrer');
    expect(link).toHaveAttribute('href', 'https://example.com');
  });

  it('empty text renders without error', () => {
    const { container } = render(<MarkdownMessage text="" />);

    expect(container.querySelector('.message-markdown')).not.toBeNull();
  });
});
