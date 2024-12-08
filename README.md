# Capturescu

This is merely an experiment to see if i can learn and use swift to build an application. It's not ready, it has lots of things that are still needed, but it was very fun and rewarding.
I have learned a lot of things, learned to hate other things(like having to deal with xcode), but most importantly, i've learned to let it go(https://news.ycombinator.com/item?id=42261197).

## Features

Has all the abilities that a barebones screenshot annotation tool would have, except some of the are half-baked.
I can copy/paste an image, add freehand drawing, arrows, shapes, text, and also move or delete them.

## Todo

- improve the keyboard shortcut manager
- improve the pointer tools
- add editing to the text marker
- reimplement copy/paste with the help of the new shortcut manager

#### Leftover notes

[composing swiftui gesture](https://developer.apple.com/documentation/swiftui/composing-swiftui-gestures)

[exclusive gestures](https://developer.apple.com/documentation/swiftui/exclusivegesture)

- use the composing gestures to handle clicks inside the pointer view
- implement editing mode on the text marker
- calculate the text marker width on end so that multiple markers don’t appear as having the same width
- re-implement copy/paste screenshot functionality
