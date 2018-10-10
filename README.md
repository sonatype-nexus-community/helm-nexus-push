<!--

 Copyright 2018-present Sonatype, Inc.
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.

-->
# Helm Nexus Repository Push

A Helm plugin that pushes a chart directory or packaged chart tgz to a specified
Nexus Helm repo.

## Installation

  * `helm plugin install --version master https://github.com/sonatype-nexus-community/helm-nexus-push.git`
  * `helm nexus-push --help`

## Updates

  * `cd $HELM_HOME/plugins/nexus-push`
  * `git pull`

## Usage

  * `helm nexus-push myrepo mychart-0.0.1.tgz`
  * `helm nexus-push myrepo ./mychart`

Additional help available `helm nexus-push --help`

## The Fine Print

It is worth noting that this is **NOT SUPPORTED** by Sonatype, and is a 
contribution of the community back to the open source community (read: you!)

Remember:

* Use this contribution at the risk tolerance that you have
* Do NOT file Sonatype support tickets related to Helm support in regard to this plugin
* DO file issues here on GitHub, so that the community can pitch in

Phew, that was easier than I thought. Last but not least of all:

Have fun creating and using this plugin and the Nexus platform, we are glad to have you here!

## Getting help

Looking to contribute to our code but need some help? There's a few ways to get information:

* Chat with us on [Gitter](https://gitter.im/sonatype-nexus-community/nexus-developers)
* Connect with us on [Twitter](https://twitter.com/sonatypeDev)
* Log an issue here on GitHub
