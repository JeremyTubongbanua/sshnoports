import 'package:args/args.dart';
import 'package:noports_core/sshnp_params.dart';
import 'package:test/test.dart';

void main() {
  group('args parser tests', () {
    test('test mandatory args', () {
      ArgParser parser =
          SSHNPArg.createArgParser(parserType: ParserType.commandLine);
      // As of version 2.4.2 of the args package, exceptions regarding
      // mandatory options are not thrown when the args are parsed,
      // but when trying to retrieve a mandatory option.
      // See https://pub.dev/packages/args/changelog

      List<String> args = [];
      expect(() => parser.parse(args)['from'], throwsA(isA<ArgumentError>()));

      args.addAll(['-f', '@alice']);
      expect(parser.parse(args)['from'], '@alice');
      expect(() => parser.parse(args)['to'], throwsA(isA<ArgumentError>()));

      args.addAll(['-t', '@bob']);
      expect(parser.parse(args)['from'], '@alice');
      expect(parser.parse(args)['to'], '@bob');
      expect(() => parser.parse(args)['host'], throwsA(isA<ArgumentError>()));

      args.addAll(['-h', 'host.subdomain.test']);
      expect(parser.parse(args)['from'], '@alice');
      expect(parser.parse(args)['to'], '@bob');
      expect(parser.parse(args)['host'], 'host.subdomain.test');
    });

    test('test parsed args with only mandatory provided', () {
      // TODO fix these params with new public API

      List<String> args = [];
      args.addAll(['-f', '@alice']);
      args.addAll(['-t', '@bob']);
      args.addAll(['-h', 'host.subdomain.test']);
      var p = SSHNPParams.fromPartial(SSHNPPartialParams.fromArgList(args));
      expect(p.clientAtSign, '@alice');
      expect(p.sshnpdAtSign, '@bob');
      expect(p.host, 'host.subdomain.test');
      expect(p.device, 'default');
      expect(p.port, 22);
      expect(p.localPort, 0);
      expect(p.sendSshPublicKey, '');
      expect(p.localSshOptions, []);
      expect(p.sshAlgorithm, SupportedSSHAlgorithm.ed25519);
      expect(p.verbose, false);
      expect(p.remoteUsername, null);
    });

    test('test parsed args with non-mandatory args provided', () {
      List<String> args = [];
      args.addAll(['-f', '@alice']);
      args.addAll(['-t', '@bob']);
      args.addAll(['-h', 'host.subdomain.test']);

      // TODO fix these params with new public API
      args.addAll([
        '--device',
        'ancient_pc',
        '--port',
        '56789',
        '--local-port',
        '98765',
        '--key-file',
        '/tmp/temp_keys.json',
        '--ssh-public-key',
        'sekrit.pub',
        '--local-ssh-options',
        '--arg 2 --arg 4 foo bar -x',
        '--remote-user-name',
        'gary',
        '-v',
        '--ssh-algorithm',
        'ssh-rsa'
      ]);
      var p = SSHNPParams.fromPartial(SSHNPPartialParams.fromArgList(args));
      expect(p.clientAtSign, '@alice');
      expect(p.sshnpdAtSign, '@bob');
      expect(p.host, 'host.subdomain.test');

      expect(p.device, 'ancient_pc');
      expect(p.port, 56789);
      expect(p.localPort, 98765);
      expect(p.atKeysFilePath, '/tmp/temp_keys.json');
      expect(p.sendSshPublicKey, 'sekrit.pub');
      expect(p.localSshOptions, ['--arg 2 --arg 4 foo bar -x']);
      expect(p.sshAlgorithm, SupportedSSHAlgorithm.rsa);
      expect(p.verbose, true);
      expect(p.remoteUsername, 'gary');
    });
  });
}
