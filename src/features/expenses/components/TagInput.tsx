import { useState } from 'react';
import { Pressable, StyleSheet, View } from 'react-native';
import { AppText } from '../../../components/AppText';
import { Icon } from '../../../components/Icon';
import { TextField } from '../../../components/TextField';
import { useTheme } from '../../../theme/ThemeProvider';

interface TagInputProps {
  label: string;
  placeholder: string;
  tags: string[];
  onChange: (tags: string[]) => void;
}

const MAX_TAGS = 10;

/** Free-text tags, committed on submit and de-duplicated case-insensitively. */
export function TagInput({ label, placeholder, tags, onChange }: TagInputProps) {
  const theme = useTheme();
  const [draft, setDraft] = useState('');

  const addTag = () => {
    const value = draft.trim();
    if (!value || tags.length >= MAX_TAGS) {
      setDraft('');
      return;
    }
    const exists = tags.some(tag => tag.toLowerCase() === value.toLowerCase());
    if (!exists) {
      onChange([...tags, value]);
    }
    setDraft('');
  };

  return (
    <View>
      <TextField
        label={label}
        placeholder={placeholder}
        value={draft}
        onChangeText={setDraft}
        onSubmitEditing={addTag}
        onBlur={addTag}
        returnKeyType="done"
        maxLength={24}
      />
      {tags.length > 0 ? (
        <View style={[styles.tagRow, { marginTop: theme.spacing.sm }]}>
          {tags.map(tag => (
            <Pressable
              key={tag}
              onPress={() => onChange(tags.filter(item => item !== tag))}
              accessibilityRole="button"
              accessibilityLabel={`Remove tag ${tag}`}
              style={[
                styles.tag,
                {
                  backgroundColor: theme.colors.surfaceContainer,
                  borderRadius: theme.radius.full,
                  paddingHorizontal: theme.spacing.smd,
                  paddingVertical: theme.spacing.xs,
                },
              ]}
            >
              <AppText variant="caption" color="textSecondary">
                {tag}
              </AppText>
              <Icon name="close" size={14} color="textTertiary" style={styles.tagIcon} />
            </Pressable>
          ))}
        </View>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  tagRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  tag: { flexDirection: 'row', alignItems: 'center' },
  tagIcon: { marginLeft: 4 },
});
