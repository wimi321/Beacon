import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { formatModelTextForDisplay } from '../lib/modelText';
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

  it('renders compact model survival lists as separated markdown list items', () => {
    const text = formatModelTextForDisplay(
      '4. 优先保障基本生存：立即优先建立以下三件事： • 保温。 • 饮水。 • 求救信号。 5. 谨慎行动：不要盲目赶路。 6. 规避危险地形：不要穿越陡坡。',
    );
    const { container } = render(<MarkdownMessage text={text} />);

    expect(container.querySelectorAll('li')).toHaveLength(6);
    expect(screen.getByText('求救信号。')).toBeInTheDocument();
    expect(screen.getByText('谨慎行动：不要盲目赶路。')).toBeInTheDocument();
    expect(screen.getByText('规避危险地形：不要穿越陡坡。')).toBeInTheDocument();
  });
});
