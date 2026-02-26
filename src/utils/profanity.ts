import { Filter } from 'bad-words'

const filter = new Filter()

export function containsProfanity(value: string) {
  return filter.isProfane(value)
}
